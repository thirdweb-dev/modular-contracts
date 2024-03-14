// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/hook/ERC721Hook.sol";
import "src/hook/ERC20Hook.sol";

contract MockOneHookImpl is ERC721Hook {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
    }
}

contract MockFourHookImpl is ERC721Hook {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG() | BEFORE_TRANSFER_FLAG() | BEFORE_BURN_FLAG() | BEFORE_APPROVE_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
    }
}

contract MockOneHookImpl20 is ERC20Hook {
    constructor() {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
    }
}

contract MockFourHookImpl20 is ERC20Hook {
    constructor() {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG() | BEFORE_TRANSFER_FLAG() | BEFORE_BURN_FLAG() | BEFORE_APPROVE_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
    }
}
