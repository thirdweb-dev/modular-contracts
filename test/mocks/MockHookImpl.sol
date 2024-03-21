// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/hook/ERC721Hook.sol";

contract MockTokenURIHookImpl is ERC721Hook {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = ON_TOKEN_URI_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockOneHookImpl is ERC721Hook {
    constructor() {}

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_TRANSFER_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockFourHookImpl is ERC721Hook {
    constructor() {}

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG() | BEFORE_TRANSFER_FLAG() | BEFORE_BURN_FLAG() | BEFORE_APPROVE_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}
