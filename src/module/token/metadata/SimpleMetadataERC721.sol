// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
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

contract SimpleMetadataERC721 is Module {

    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the metadata URI for a token is updated.
    event MetadataUpdate(uint256 id);

    /// @notice Emitted when the metadata URI is queried for non-existent token.
    error MetadataNoMetadataForTokenId();

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setTokenURI.selector, permissionBits: Role._MINTER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) public view returns (string memory uri) {
        uri = SimpleMetadataStorage.data().uris[_id];
        if (bytes(uri).length == 0) {
            revert MetadataNoMetadataForTokenId();
        }
        return uri;
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
