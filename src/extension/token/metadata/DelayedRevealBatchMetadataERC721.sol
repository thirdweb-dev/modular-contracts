// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {LibString} from "@solady/utils/LibString.sol";

library DelayedRevealBatchMetadataStorage {
    /// @custom:storage-location erc7201:delayed.reveal.batch.metadata.storage
    bytes32 public constant DELAYED_REVEAL_BATCH_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("delayed.reveal.batch.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => tokenId range end
        mapping(address => uint256[]) tokenIdRangeEnd;
        // token => next tokenId as range start
        mapping(address => uint256) nextTokenIdRangeStart;
        // token => tokenId range end => baseURI of range
        mapping(address => mapping(uint256 => string)) baseURIOfTokenIdRange;
        ///  token => tokenId range end => encrypted data for that range
        mapping(address => mapping(uint256 => bytes)) encryptedData;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = DELAYED_REVEAL_BATCH_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract DelayedRevealBatchMetadataERC721 is ModularExtension {
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

    /// @dev The contract doesn't have any url to be delayed revealed
    error DelayedRevealNothingToReveal();

    /// @dev The result of the returned an incorrect hash
    error DelayedRevealIncorrectResultHash(bytes32 expected, bytes32 actual);

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

    /// @dev Emitted when tokens are revealed.
    event TokenURIRevealed(uint256 indexed index, string revealedURI);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector, CallType.STATICCALL);
        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.uploadMetadata.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.getAllMetadataBatches.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.reveal.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.getRevealURI.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[4] =
            FallbackFunction({selector: this.encryptDecrypt.selector, callType: CallType.STATICCALL, permissionBits: 0});

        config.requiredInterfaceId = 0x80ac58cd; // ERC721.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory) {
        address token = msg.sender;
        (string memory batchUri, bool isEncrypted) = _getBaseURI(token, _id);

        if (isEncrypted) {
            return string(abi.encodePacked(batchUri, "0"));
        } else {
            return string(abi.encodePacked(batchUri, _id.toString()));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all metadata batches for a token.
    function getAllMetadataBatches() external view returns (MetadataBatch[] memory) {
        address token = msg.sender;

        uint256[] memory rangeEnds = _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[token];
        uint256 numOfBatches = rangeEnds.length;

        MetadataBatch[] memory batches = new MetadataBatch[](rangeEnds.length);

        uint256 rangeStart = 0;
        for (uint256 i = 0; i < numOfBatches; i += 1) {
            batches[i] = MetadataBatch({
                startTokenIdInclusive: rangeStart,
                endTokenIdInclusive: rangeEnds[i] - 1,
                baseURI: _delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[token][rangeEnds[i]]
            });
            rangeStart = rangeEnds[i];
        }

        return batches;
    }

    /// @notice Uploads metadata for a range of tokenIds.
    function uploadMetadata(uint256 _amount, string calldata _baseURI, bytes memory _data) public virtual {
        address token = msg.sender;
        if (_amount == 0) {
            revert BatchMetadataZeroAmount();
        }

        uint256 rangeStart = _delayedRevealBatchMetadataStorage().nextTokenIdRangeStart[token];
        uint256 rangeEndNonInclusive = rangeStart + _amount;

        if (_data.length > 0) {
            (bytes memory encryptedURI, bytes32 provenanceHash) = abi.decode(_data, (bytes, bytes32));
            if (encryptedURI.length != 0 && provenanceHash != "") {
                _delayedRevealBatchMetadataStorage().encryptedData[token][rangeEndNonInclusive] = _data;
            }
        }

        _delayedRevealBatchMetadataStorage().nextTokenIdRangeStart[token] = rangeEndNonInclusive;
        _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[token].push(rangeEndNonInclusive);
        _delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[token][rangeEndNonInclusive] = _baseURI;

        emit NewMetadataBatch(token, rangeStart, rangeEndNonInclusive, _baseURI);
    }

    /// @notice reveals the URI for a range of 'delayed-reveal' tokens.
    function reveal(uint256 _index, bytes calldata _key) public returns (string memory revealedURI) {
        address token = msg.sender;
        uint256 _rangeEndNonInclusive = _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[token][_index];
        revealedURI = _getRevealURI(token, _rangeEndNonInclusive, _key);

        _delayedRevealBatchMetadataStorage().encryptedData[token][_rangeEndNonInclusive] = "";
        _delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[token][_rangeEndNonInclusive] = revealedURI;

        emit TokenURIRevealed(_index, revealedURI);
    }

    /// @notice unencrypted URI for a range of 'delayed-reveal' tokens.
    function getRevealURI(uint256 _index, bytes calldata _key) public view returns (string memory) {
        address token = msg.sender;
        uint256 _rangeEndNonInclusive = _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[token][_index];

        return _getRevealURI(token, _rangeEndNonInclusive, _key);
    }

    /**
     *  @notice         Encrypt/decrypt data on chain.
     *  @dev            Encrypt/decrypt given `data` with `key`. Uses inline assembly.
     *                  See: https://ethereum.stackexchange.com/questions/69825/decrypt-message-on-chain
     */
    function encryptDecrypt(bytes memory data, bytes calldata key) public pure returns (bytes memory result) {
        // Store data length on stack for later use
        uint256 length = data.length;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Set result to free memory pointer
            result := mload(0x40)
            // Increase free memory pointer by lenght + 32
            mstore(0x40, add(add(result, length), 32))
            // Set result length
            mstore(result, length)
        }

        // Iterate over the data stepping by 32 bytes
        for (uint256 i = 0; i < length; i += 32) {
            // Generate hash of the key and offset
            bytes32 hash = keccak256(abi.encodePacked(key, i));

            bytes32 chunk;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Read 32-bytes data chunk
                chunk := mload(add(data, add(i, 32)))
            }
            // XOR the chunk with hash
            chunk ^= hash;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Write 32-byte encrypted chunk
                mstore(add(result, add(i, 32)), chunk)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the baseURI for a token. The intended metadata URI for the token is baseURI + tokenId.
    function _getBaseURI(address _token, uint256 _tokenId) internal view returns (string memory, bool) {
        uint256[] memory rangeEnds = _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[_token];
        uint256 numOfBatches = rangeEnds.length;

        for (uint256 i = 0; i < numOfBatches; i += 1) {
            if (_tokenId < rangeEnds[i]) {
                bytes memory encryptedData = _delayedRevealBatchMetadataStorage().encryptedData[_token][rangeEnds[i]];
                bool isEncrypted = encryptedData.length > 0;

                return (_delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[_token][rangeEnds[i]], isEncrypted);
            }
        }
        revert BatchMetadataNoMetadataForTokenId();
    }

    /// @notice unencrypted URI for a range of 'delayed-reveal' tokens.
    function _getRevealURI(address _token, uint256 _rangeEndNonInclusive, bytes calldata _key)
        internal
        view
        returns (string memory revealedURI)
    {
        bytes memory data = _delayedRevealBatchMetadataStorage().encryptedData[_token][_rangeEndNonInclusive];
        if (data.length == 0) {
            revert DelayedRevealNothingToReveal();
        }

        (bytes memory encryptedURI, bytes32 provenanceHash) = abi.decode(data, (bytes, bytes32));

        revealedURI = string(encryptDecrypt(encryptedURI, _key));

        if (keccak256(abi.encodePacked(revealedURI, _key, block.chainid)) != provenanceHash) {
            revert DelayedRevealIncorrectResultHash(
                provenanceHash, keccak256(abi.encodePacked(revealedURI, _key, block.chainid))
            );
        }
    }

    function _delayedRevealBatchMetadataStorage()
        internal
        pure
        returns (DelayedRevealBatchMetadataStorage.Data storage)
    {
        return DelayedRevealBatchMetadataStorage.data();
    }
}
