// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";
import {LibString} from "@solady/utils/LibString.sol";

library BatchMetadataStorage {
    /// @custom:storage-location erc7201:batch.metadata.storage
    bytes32 public constant BATCH_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("batch.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => tokenId range end
        mapping(address => uint256[]) tokenIdRangeEnd;
        // token => next tokenId as range start
        mapping(address => uint256) nextTokenIdRangeStart;
        // token => tokenId range end => baseURI of range
        mapping(address => mapping(uint256 => string)) baseURIOfTokenIdRange;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BATCH_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract BatchMetadata is IExtensionContract {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *   @notice MetadataBatch struct to store metadata for a range of tokenIds.
     *   @param startTokenIdInclusive The first tokenId in the range.
     *   @param endTokenIdNonInclusive The last tokenId in the range.
     *   @param baseURI The base URI for the range.
     */
    struct MetadataBatch {
        uint256 startTokenIdInclusive;
        uint256 endTokenIdInclusive;
        string baseURI;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when uploading metadata for zero tokens.
    error BatchMetadataZeroAmount();

    /// @dev Emitted when trying to fetch metadata for a token that has no metadata.
    error BatchMetadataNoMetadataForTokenId();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when a new metadata batch is uploaded.
    event NewMetadataBatch(
        address indexed token,
        uint256 indexed startTokenIdInclusive,
        uint256 indexed endTokenIdNonInclusive,
        string baseURI
    );

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.extensionABI = new ExtensionFunction[](2);

        config.callbackFunctions[0] = this.onTokenURI.selector;
        config.extensionABI[0] =
            ExtensionFunction({selector: this.uploadMetadata.selector, callType: CallType.CALL, permissioned: true});
        config.extensionABI[1] = ExtensionFunction({
            selector: this.getAllMetadataBatches.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory) {
        address token = msg.sender;
        string memory batchUri = _getBaseURI(token, _id);

        return string(abi.encodePacked(batchUri, _id.toString()));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all metadata batches for a token.
    function getAllMetadataBatches() external view returns (MetadataBatch[] memory) {
        address token = msg.sender;

        uint256[] memory rangeEnds = _batchMetadataStorage().tokenIdRangeEnd[token];
        uint256 numOfBatches = rangeEnds.length;

        MetadataBatch[] memory batches = new MetadataBatch[](rangeEnds.length);

        uint256 rangeStart = 0;
        for (uint256 i = 0; i < numOfBatches; i += 1) {
            batches[i] = MetadataBatch({
                startTokenIdInclusive: rangeStart,
                endTokenIdInclusive: rangeEnds[i] - 1,
                baseURI: _batchMetadataStorage().baseURIOfTokenIdRange[token][rangeEnds[i]]
            });
            rangeStart = rangeEnds[i];
        }

        return batches;
    }

    /// @notice Uploads metadata for a range of tokenIds.
    function uploadMetadata(uint256 _amount, string calldata _baseURI) public virtual {
        address token = msg.sender;
        if (_amount == 0) {
            revert BatchMetadataZeroAmount();
        }

        uint256 rangeStart = _batchMetadataStorage().nextTokenIdRangeStart[token];
        uint256 rangeEndNonInclusive = rangeStart + _amount;

        _batchMetadataStorage().nextTokenIdRangeStart[token] = rangeEndNonInclusive;
        _batchMetadataStorage().tokenIdRangeEnd[token].push(rangeEndNonInclusive);
        _batchMetadataStorage().baseURIOfTokenIdRange[token][rangeEndNonInclusive] = _baseURI;

        emit NewMetadataBatch(token, rangeStart, rangeEndNonInclusive, _baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the baseURI for a token. The intended metadata URI for the token is baseURI + tokenId.
    function _getBaseURI(address _token, uint256 _tokenId) internal view returns (string memory) {
        uint256[] memory rangeEnds = _batchMetadataStorage().tokenIdRangeEnd[_token];
        uint256 numOfBatches = rangeEnds.length;

        for (uint256 i = 0; i < numOfBatches; i += 1) {
            if (_tokenId < rangeEnds[i]) {
                return _batchMetadataStorage().baseURIOfTokenIdRange[_token][rangeEnds[i]];
            }
        }
        revert BatchMetadataNoMetadataForTokenId();
    }

    function _batchMetadataStorage() internal pure returns (BatchMetadataStorage.Data storage) {
        return BatchMetadataStorage.data();
    }
}
