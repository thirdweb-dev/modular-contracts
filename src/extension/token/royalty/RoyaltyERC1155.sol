// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {RoyaltyERC721} from "./RoyaltyERC721.sol";

contract RoyaltyERC1155 is RoyaltyERC721 {
    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](0);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.royaltyInfo.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.getDefaultRoyaltyInfo.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getRoyaltyInfoForToken.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setDefaultRoyaltyInfo.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[4] = FallbackFunction({
            selector: this.setRoyaltyInfoForToken.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x2a55205a; // IERC2981.

        config.requiredInterfaceId = 0xd9b67a26; // ERC1155
    }
}
