// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/extension/TokenHook.sol";

contract MockOneHookImpl is TokenHook {
    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG;
    }
}

contract MockFourHookImpl is TokenHook {
    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | BEFORE_TRANSFER_FLAG | BEFORE_BURN_FLAG | BEFORE_APPROVE_FLAG;
    }
}
