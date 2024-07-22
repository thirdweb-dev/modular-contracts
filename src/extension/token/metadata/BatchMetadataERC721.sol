// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {LibString} from "@solady/utils/LibString.sol";

library BatchMetadataStorage {

    /// @custom:storage-location erc7201:token.metadata.batch
    bytes32 public constant BATCH_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.metadata.batch")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // tokenId range end
        uint256[] tokenIdRangeEnd;
        // next tokenId as range start
        uint256 nextTokenIdRangeStart;
        // tokenId range end => baseURI of range
        mapping(uint256 => string) baseURIOfTokenIdRange;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BATCH_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract BatchMetadataERC721 is ModularExtension {

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
        uint256 indexed startTokenIdInclusive, uint256 indexed endTokenIdNonInclusive, string baseURI
    );

    /// @dev ERC-4906 Metadata Update.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](2);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.uploadMetadata.selector, permissionBits: Role._MINTER_ROLE});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.getAllMetadataBatches.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory) {
        string memory batchUri = _getBaseURI(_id);

        return string(abi.encodePacked(batchUri, _id.toString()));
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all metadata batches for a token.
    function getAllMetadataBatches() external view returns (MetadataBatch[] memory) {
        uint256[] memory rangeEnds = _batchMetadataStorage().tokenIdRangeEnd;
        uint256 numOfBatches = rangeEnds.length;

        MetadataBatch[] memory batches = new MetadataBatch[](rangeEnds.length);

        uint256 rangeStart = 0;
        for (uint256 i = 0; i < numOfBatches; i += 1) {
            batches[i] = MetadataBatch({
                startTokenIdInclusive: rangeStart,
                endTokenIdInclusive: rangeEnds[i] - 1,
                baseURI: _batchMetadataStorage().baseURIOfTokenIdRange[rangeEnds[i]]
            });
            rangeStart = rangeEnds[i];
        }

        return batches;
    }

    /// @notice Uploads metadata for a range of tokenIds.
    function uploadMetadata(uint256 _amount, string calldata _baseURI) public virtual {
        if (_amount == 0) {
            revert BatchMetadataZeroAmount();
        }

        uint256 rangeStart = _batchMetadataStorage().nextTokenIdRangeStart;
        uint256 rangeEndNonInclusive = rangeStart + _amount;

        _batchMetadataStorage().nextTokenIdRangeStart = rangeEndNonInclusive;
        _batchMetadataStorage().tokenIdRangeEnd.push(rangeEndNonInclusive);
        _batchMetadataStorage().baseURIOfTokenIdRange[rangeEndNonInclusive] = _baseURI;

        emit NewMetadataBatch(rangeStart, rangeEndNonInclusive, _baseURI);
        emit BatchMetadataUpdate(rangeStart, rangeEndNonInclusive - 1);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the baseURI for a token. The intended metadata URI for the token is baseURI + tokenId.
    function _getBaseURI(uint256 _tokenId) internal view returns (string memory) {
        uint256[] memory rangeEnds = _batchMetadataStorage().tokenIdRangeEnd;
        uint256 numOfBatches = rangeEnds.length;

        for (uint256 i = 0; i < numOfBatches; i += 1) {
            if (_tokenId < rangeEnds[i]) {
                return _batchMetadataStorage().baseURIOfTokenIdRange[rangeEnds[i]];
            }
        }
        revert BatchMetadataNoMetadataForTokenId();
    }

    function _batchMetadataStorage() internal pure returns (BatchMetadataStorage.Data storage) {
        return BatchMetadataStorage.data();
    }

}
