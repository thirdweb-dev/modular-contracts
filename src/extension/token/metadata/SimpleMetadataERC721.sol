// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {LibString} from "@solady/utils/LibString.sol";

library SimpleMetadataStorage {
    /// @custom:storage-location erc7201:simple.metadata.storage
    bytes32 public constant SIMPLE_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("simple.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice Mapping from token => base URI
        mapping(address => mapping(uint256 => string)) uris;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SIMPLE_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract SimpleMetadataERC721 is ModularExtension {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the metadata URI for a token is updated.
    event MetadataUpdate(address indexed token, uint256 id);

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
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector, CallType.CALL);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setTokenURI.selector, callType: CallType.CALL, permissionBits: 0});

        config.requiredInterfaceId = 0x80ac58cd; // ERC721
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the metadata URI for a token.
    function setTokenURI(uint256 _id, string calldata _uri) external {
        address token = msg.sender;

        SimpleMetadataStorage.data().uris[token][_id] = _uri;
        emit MetadataUpdate(token, _id);
    }
}
