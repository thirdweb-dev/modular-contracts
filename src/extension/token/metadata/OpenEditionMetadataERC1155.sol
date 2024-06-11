// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {OpenEditionMetadataERC721} from "./OpenEditionMetadataERC721.sol";
import {Role} from "../../../Role.sol";

contract OpenEditionMetadataERC1155 is OpenEditionMetadataERC721 {
    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setSharedMetadata.selector, permissionBits: Role._MINTER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }
}
