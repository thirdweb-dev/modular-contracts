// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {LibString} from "@solady/utils/LibString.sol";

library SimpleMetadataStorage {
    /// @custom:storage-location erc7201:token.metadata.simple
    bytes32 public constant SIMPLE_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.metadata.simple")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // base URI
        mapping(uint256 => string) uris;
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
    event MetadataUpdate(uint256 id);

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setTokenURI.selector, permissionBits: Role._MINTER_ROLE});

        config.requiredInterfaceId = 0x80ac58cd; // ERC721
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory) {
        return SimpleMetadataStorage.data().uris[_id];
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the metadata URI for a token.
    function setTokenURI(uint256 _id, string calldata _uri) external {
        SimpleMetadataStorage.data().uris[_id] = _uri;
        emit MetadataUpdate(_id);
    }
}
