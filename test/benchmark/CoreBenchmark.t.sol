// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ModularCore} from "src/ModularCore.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {IModularModule, IModuleConfig} from "src/interface/IModularModule.sol";

contract MockBase {

    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getCallbacks() internal pure virtual returns (IModuleConfig.CallbackFunction[] memory functions) {
        functions = new IModuleConfig.CallbackFunction[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
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

contract MockModule is MockBase, IModularModule {

    function onInstall(bytes memory data) external {}

    function onUninstall(bytes memory data) external {}

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }

}

contract MockModuleWithFunctions is MockBase, IModularModule {

    event CallbackFunctionOne();

    uint256 public constant CALLER_ROLE = 1 << 0;

    function onInstall(bytes memory data) external {}

    function onUninstall(bytes memory data) external {}

    function getCallbacks() internal pure override returns (IModuleConfig.CallbackFunction[] memory functions) {
        functions = new IModuleConfig.CallbackFunction[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
        }
        functions[NUMBER_OF_CALLBACK].selector = this.callbackFunctionOne.selector;
    }

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](6);
        functions[0] = FallbackFunction({selector: bytes4(keccak256("notPermissioned_call()")), permissionBits: 0});
        functions[1] =
            FallbackFunction({selector: bytes4(keccak256("notPermissioned_delegatecall()")), permissionBits: 0});
        functions[2] =
            FallbackFunction({selector: bytes4(keccak256("notPermissioned_staticcall()")), permissionBits: 0});
        functions[3] =
            FallbackFunction({selector: bytes4(keccak256("permissioned_call()")), permissionBits: CALLER_ROLE});
        functions[4] =
            FallbackFunction({selector: bytes4(keccak256("permissioned_delegatecall()")), permissionBits: CALLER_ROLE});
        functions[5] =
            FallbackFunction({selector: bytes4(keccak256("permissioned_staticcall()")), permissionBits: CALLER_ROLE});
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
    MockModule public module;
    MockCore public coreWithModules;
    MockCore public coreWithModulesNoCallback;
    MockModuleWithFunctions public moduleWithFunctions;

    function setUp() public {
        vm.startPrank(address(0x42));
        core = new MockCore();
        coreWithModules = new MockCore();
        coreWithModulesNoCallback = new MockCore();
        module = new MockModule();
        moduleWithFunctions = new MockModuleWithFunctions();

        coreWithModulesNoCallback.installModule(address(module), "");
        coreWithModules.installModule(address(moduleWithFunctions), "");
    }

    function test_deployCore() public {
        new MockCoreMinimal();
    }

    function test_deployModule() public {
        new MockModule();
    }

    function test_installModule() public {
        core.installModule(address(module), "");
    }

    function test_uninstallModule() public {
        vm.pauseGasMetering();
        core.installModule(address(module), "");
        vm.resumeGasMetering();

        core.uninstallModule(address(module), "");
    }

    function test_module_callFunction_notPermissionedExternal() public {
        (bool success,) =
            address(moduleWithFunctions).call(abi.encodeCall(MockModuleWithFunctions.notPermissioned_call, ()));
        vm.assertTrue(success);
    }

    function test_module_callFunction_notPermissionedDelegate() public {
        (bool success,) =
            address(moduleWithFunctions).call(abi.encodeCall(MockModuleWithFunctions.notPermissioned_delegatecall, ()));
        vm.assertTrue(success);
    }

    function test_core_callFunction_notPermissionedExternal() public {
        (bool success,) =
            address(coreWithModules).call(abi.encodeCall(MockModuleWithFunctions.notPermissioned_call, ()));
        vm.assertTrue(success);
    }

    function test_core_callFunction_notPermissionedDelegate() public {
        (bool success,) =
            address(coreWithModules).call(abi.encodeCall(MockModuleWithFunctions.notPermissioned_delegatecall, ()));
        vm.assertTrue(success);
    }

    function test_core_callCallbackFunction_required() public {
        (bool success,) = address(coreWithModules).call(abi.encodeCall(coreWithModules.callbackFunctionOne, ()));
        vm.assertTrue(success);
    }

    function test_core_callFunction_callback_callbackFunctionRequired() public {
        vm.expectRevert(ModularCore.CallbackFunctionRequired.selector);
        address(coreWithModulesNoCallback).call(abi.encodeCall(coreWithModulesNoCallback.callbackFunctionOne, ()));
    }

}
