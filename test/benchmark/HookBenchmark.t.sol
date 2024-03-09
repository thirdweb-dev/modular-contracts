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

contract MockCore0 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(
        address /* _caller */
    ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(
        address /* _caller */
    ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return 0;
    }
}

contract MockCore256 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(
        address /* _caller */
    ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(
        address /* _caller */
    ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return 255;
    }
}

contract HookBenchmark is Test {
    MockHook private hook;
    MockCore0 private core0;
    MockCore256 private core256;

    function setUp() public {
        hook = new MockHook();
        core0 = new MockCore0();
        core256 = new MockCore256();
    }

    function test_installHook_0() public {
        core0.installHook(hook, "");
    }

    function test_uninstallHook_0() public {
        vm.pauseGasMetering();
        core0.installHook(hook, "");
        vm.resumeGasMetering();

        core0.uninstallHook(hook);
    }

    function test_installHook_256() public {
        core256.installHook(hook, "");
    }

    function test_uninstallHook_256() public {
        vm.pauseGasMetering();
        core256.installHook(hook, "");
        vm.resumeGasMetering();

        core256.uninstallHook(hook);
    }
}
