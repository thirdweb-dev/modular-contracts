// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Role} from "../../../Role.sol";
import {OpenEditionMetadataERC721} from "./OpenEditionMetadataERC721.sol";

contract OpenEditionMetadataERC1155 is OpenEditionMetadataERC721 {

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
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
