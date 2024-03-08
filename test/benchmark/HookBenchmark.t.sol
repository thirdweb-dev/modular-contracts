// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HookInstaller} from "src/core/HookInstaller.sol";
import {IHook} from "src/interface/hook/IHook.sol";

contract MockHook is IHook {
    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = 0;
    }
}

contract MockCore is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return 0;
    }
}

contract HookBenchmark is Test {
    MockHook private hook;
    MockCore private core;

    function setUp() public {
        hook = new MockHook();
        core = new MockCore();
    }

    function test_installHook() public {
        core.installHook(hook, "");
    }

    function test_uninstallHook() public {
        vm.pauseGasMetering();
        core.installHook(hook, "");
        vm.resumeGasMetering();

        core.uninstallHook(hook);
    }
}
