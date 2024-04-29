// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IExtensionContract} from "src/interface/IExtensionContract.sol";
import {CoreContract} from "src/core/CoreContract.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";

contract MockBase {
    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getFunctionSignature()
        internal
        pure
        returns (bytes4[] memory functions)
    {
        functions = new bytes4[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = bytes4(uint32(i));
        }
    }
}

contract MockCore is MockBase, CoreContract {
    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (bytes4[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = getFunctionSignature();
    }

    function _isAuthorizedToInstallExtensions(
        address /* _target */
    ) internal pure override returns (bool) {
        return true;
    }

    function _isAuthorizedToCallExtensionFunctions(
        address /*_target*/
    ) internal pure override returns (bool) {
        return true;
    }
}

contract MockExtension is MockBase, IExtensionContract {
    function onInstall(bytes memory data) external {}

    function onUninstall(bytes memory data) external {}

    function getExtensionConfig()
        external
        pure
        override
        returns (ExtensionConfig memory config)
    {
        config.callbackFunctions = getFunctionSignature();
    }
}

contract CoreBenchmark is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Target test contracts
    MockCore public core;
    MockExtension public extension;

    function setUp() public {
        core = new MockCore();
        extension = new MockExtension();
    }

    function test_deployCore() public {
        new MockCore();
    }

    function test_deployExtension() public {
        new MockExtension();
    }

    function test_installExtension() public {
        core.installExtension(address(extension), "");
    }

    function test_uninstallExtension() public {
        vm.pauseGasMetering();
        core.installExtension(address(extension), "");
        vm.resumeGasMetering();

        core.uninstallExtension(address(extension), "");
    }
}
