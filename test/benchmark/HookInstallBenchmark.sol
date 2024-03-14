// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IHookInstaller, HookInstaller} from "src/core/HookInstaller.sol";
import {IHook} from "src/interface/hook/IHook.sol";

contract MockHook is IHook {
    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = 0;
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
    }
}

contract MockCore0 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint8) {
        return 0;
    }
}

contract MockCore256 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint8) {
        return 255;
    }
}

contract HookInstallBenchmarkTest is Test {
    MockHook private hook;

    MockCore0 private core0;
    MockCore0 private core0Preinstalled;

    MockCore256 private core256;
    MockCore256 private core256Preinstalled;

    function setUp() public {
        hook = new MockHook();

        core0 = new MockCore0();
        core0Preinstalled = new MockCore0();
        core0Preinstalled.installHook(IHookInstaller.InstallHookParams(hook, 0, ""));

        core256 = new MockCore256();
        core256Preinstalled = new MockCore256();
        core256Preinstalled.installHook(IHookInstaller.InstallHookParams(hook, 0, ""));
    }

    function test_installHook_0() public {
        vm.pauseGasMetering();
        MockHook hookToInstall = hook;
        MockCore0 core = core0;
        vm.resumeGasMetering();
        core.installHook(IHookInstaller.InstallHookParams(hookToInstall, 0, ""));
    }

    function test_uninstallHook_0() public {
        vm.pauseGasMetering();
        MockHook hookToUninstall = hook;
        MockCore0 core = core0Preinstalled;
        vm.resumeGasMetering();

        core.uninstallHook(hookToUninstall);
    }

    function test_installHook256() public {
        vm.pauseGasMetering();
        MockHook hookToInstall = hook;
        MockCore256 core = core256;
        vm.resumeGasMetering();
        core.installHook(IHookInstaller.InstallHookParams(hookToInstall, 0, ""));
    }

    function test_uninstallHook_256() public {
        vm.pauseGasMetering();
        MockHook hookToUninstall = hook;
        MockCore256 core = core256Preinstalled;
        vm.resumeGasMetering();

        core.uninstallHook(hookToUninstall);
    }
}
