// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IHookInstaller, HookInstaller} from "src/core/HookInstaller.sol";
import {IHook} from "src/interface/IHook.sol";

contract MockHook0 is IHook {
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = 0;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockHook256 is IHook {
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = 256;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockCore0 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _isAuthorizedToCallHookFallbackFunction(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the supported hook flags.
    function _supportedHookFlags() internal view virtual override returns (uint256) {
        return 0;
    }
}

contract MockCore256 is HookInstaller {
    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Returns whether the caller can write to hooks.
    function _isAuthorizedToCallHookFallbackFunction(address /* _caller */ ) internal pure override returns (bool) {
        return true;
    }

    /// @dev Should return the supported hook flags.
    function _supportedHookFlags() internal view virtual override returns (uint256) {
        return 256;
    }
}

contract HookInstallBenchmarkTest is Test {
    MockHook0 private hook0;
    MockHook256 private hook256;

    MockCore0 private core0;
    MockCore0 private core0Preinstalled;

    MockCore256 private core256;
    MockCore256 private core256Preinstalled;

    function setUp() public {
        hook0 = new MockHook0();
        hook256 = new MockHook256();

        core0 = new MockCore0();
        core0Preinstalled = new MockCore0();
        core0Preinstalled.installHook(IHookInstaller.InstallHookParams(hook0, 0, ""));

        core256 = new MockCore256();
        core256Preinstalled = new MockCore256();
        core256Preinstalled.installHook(IHookInstaller.InstallHookParams(hook256, 0, ""));
    }

    function test_installHook_0() public {
        vm.pauseGasMetering();
        MockHook0 hookToInstall = hook0;
        MockCore0 core = core0;
        vm.resumeGasMetering();
        core.installHook(IHookInstaller.InstallHookParams(hookToInstall, 0, ""));
    }

    function test_uninstallHook_0() public {
        vm.pauseGasMetering();
        MockCore0 core = core0Preinstalled;
        vm.resumeGasMetering();

        core.uninstallHook(0);
    }

    function test_installHook256() public {
        vm.pauseGasMetering();
        MockHook256 hookToInstall = hook256;
        MockCore256 core = core256;
        vm.resumeGasMetering();
        core.installHook(IHookInstaller.InstallHookParams(hookToInstall, 0, ""));
    }

    function test_uninstallHook_256() public {
        vm.pauseGasMetering();
        MockCore256 core = core256Preinstalled;
        vm.resumeGasMetering();

        core.uninstallHook(256);
    }
}
