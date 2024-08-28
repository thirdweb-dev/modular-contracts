// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Role} from "../../../Role.sol";
import {BatchMetadataERC721} from "./BatchMetadataERC721.sol";

contract BatchMetadataERC1155 is BatchMetadataERC721 {

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](3);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.uploadMetadata.selector, permissionBits: Role._MINTER_ROLE});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.getAllMetadataBatches.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.getNextTokenIdRangeStart.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

}
