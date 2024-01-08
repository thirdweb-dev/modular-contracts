// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/extension/TokenHook.sol";

contract MockOneHookImpl is TokenHook {

    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG;
    }
}

contract MockFiveHookImpl is TokenHook {

    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG | AFTER_TRANSFER_FLAG | BEFORE_APPROVE_FLAG | AFTER_APPROVE_FLAG | BEFORE_BURN_FLAG;
    }
}