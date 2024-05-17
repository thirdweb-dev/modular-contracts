// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IModularExtension, IExtensionConfig} from "src/interface/IModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";

contract MockBase {
    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getCallbacks() internal pure virtual returns (IExtensionConfig.CallbackFunction[] memory functions) {
        functions = new IExtensionConfig.CallbackFunction[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
            functions[i].callType = IExtensionConfig.CallType.CALL;
        }
    }
}

contract MockCoreMinimal is MockBase, ModularCore {
    constructor() {
        _initializeOwner(msg.sender);
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = getCallbackFunctions();
    }

    function getCallbackFunctions() internal pure returns (SupportedCallbackFunction[] memory functions) {
        functions = new SupportedCallbackFunction[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = SupportedCallbackFunction({selector: bytes4(uint32(i)), mode: CallbackMode.OPTIONAL});
        }
    }
}

contract MockCore is MockBase, ModularCore {
    constructor() {
        _initializeOwner(msg.sender);
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = getCallbackFunctions();
    }

    function getCallbackFunctions() internal pure returns (SupportedCallbackFunction[] memory functions) {
        functions = new SupportedCallbackFunction[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = SupportedCallbackFunction({selector: bytes4(uint32(i)), mode: CallbackMode.OPTIONAL});
        }

        functions[NUMBER_OF_CALLBACK] =
            SupportedCallbackFunction({selector: this.callbackFunctionOne.selector, mode: CallbackMode.REQUIRED});
    }

    function callbackFunctionOne() external {
        _executeCallbackFunction(msg.sig, abi.encodeCall(this.callbackFunctionOne, ()));
    }
}

contract MockExtension is MockBase, IModularExtension {
    function onInstall(address sender, bytes memory data) external {}

    function onUninstall(address sender, bytes memory data) external {}

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }
}

contract MockExtensionWithFunctions is MockBase, IModularExtension {
    event CallbackFunctionOne();

    uint256 public constant CALLER_ROLE = 1 << 0;

    function onInstall(address sender, bytes memory data) external {}

    function onUninstall(address sender, bytes memory data) external {}

    function getCallbacks() internal pure override returns (IExtensionConfig.CallbackFunction[] memory functions) {
        functions = new IExtensionConfig.CallbackFunction[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
            functions[i].callType = IExtensionConfig.CallType.CALL;
        }
        functions[NUMBER_OF_CALLBACK].selector = this.callbackFunctionOne.selector;
        functions[NUMBER_OF_CALLBACK].callType = IExtensionConfig.CallType.CALL;
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](6);
        functions[0] = FallbackFunction({
            selector: bytes4(keccak256("notPermissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
        functions[1] = FallbackFunction({
            selector: bytes4(keccak256("notPermissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: 0
        });
        functions[2] = FallbackFunction({
            selector: bytes4(keccak256("notPermissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        functions[3] = FallbackFunction({
            selector: bytes4(keccak256("permissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[4] = FallbackFunction({
            selector: bytes4(keccak256("permissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: CALLER_ROLE
        });
        functions[5] = FallbackFunction({
            selector: bytes4(keccak256("permissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: CALLER_ROLE
        });
        config.fallbackFunctions = functions;
    }

    function callbackFunctionOne() external {
        emit CallbackFunctionOne();
    }

    function notPermissioned_call() external {}

    function notPermissioned_delegatecall() external {}

    function notPermissioned_staticcall() external view {}

    function permissioned_call() external {}

    function permissioned_delegatecall() external {}

    function permissioned_staticcall() external view {}
}

contract CoreBenchmark is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Target test contracts
    MockCore public core;
    MockExtension public extension;
    MockCore public coreWithExtensions;
    MockCore public coreWithExtensionsNoCallback;
    MockExtensionWithFunctions public extensionWithFunctions;

    function setUp() public {
        vm.startPrank(address(0x42));
        core = new MockCore();
        coreWithExtensions = new MockCore();
        coreWithExtensionsNoCallback = new MockCore();
        extension = new MockExtension();
        extensionWithFunctions = new MockExtensionWithFunctions();

        coreWithExtensionsNoCallback.installExtension(address(extension), "");
        coreWithExtensions.installExtension(address(extensionWithFunctions), "");
    }

    function test_deployCore() public {
        new MockCoreMinimal();
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

    function test_extension_callFunction_notPermissionedExternal() public {
        (bool success,) =
            address(extensionWithFunctions).call(abi.encodeCall(MockExtensionWithFunctions.notPermissioned_call, ()));
        vm.assertTrue(success);
    }

    function test_extension_callFunction_notPermissionedDelegate() public {
        (bool success,) = address(extensionWithFunctions).call(
            abi.encodeCall(MockExtensionWithFunctions.notPermissioned_delegatecall, ())
        );
        vm.assertTrue(success);
    }

    function test_core_callFunction_notPermissionedExternal() public {
        (bool success,) =
            address(coreWithExtensions).call(abi.encodeCall(MockExtensionWithFunctions.notPermissioned_call, ()));
        vm.assertTrue(success);
    }

    function test_core_callFunction_notPermissionedDelegate() public {
        (bool success,) = address(coreWithExtensions).call(
            abi.encodeCall(MockExtensionWithFunctions.notPermissioned_delegatecall, ())
        );
        vm.assertTrue(success);
    }

    function test_core_callCallbackFunction_required() public {
        (bool success,) = address(coreWithExtensions).call(abi.encodeCall(coreWithExtensions.callbackFunctionOne, ()));
        vm.assertTrue(success);
    }

    function test_core_callFunction_callback_callbackFunctionRequired() public {
        vm.expectRevert(ModularCore.CallbackFunctionRequired.selector);
        address(coreWithExtensionsNoCallback).call(abi.encodeCall(coreWithExtensionsNoCallback.callbackFunctionOne, ()));
    }
}
