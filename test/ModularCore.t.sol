// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// Test utils
import {Test} from "forge-std/Test.sol";

// Target contract

import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";
import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

contract MockBase {

    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getCallbacks() internal pure virtual returns (IModuleConfig.CallbackFunction[] memory functions) {
        functions = new IModuleConfig.CallbackFunction[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
        }
    }

}

contract MockCore is MockBase, Core {

    constructor(address _owner) {
        _initializeOwner(_owner);
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

contract MockModuleWithFunctions is MockBase, Module {

    event CallbackFunctionOne();
    event FallbackFunctionCalled();

    uint256 public constant CALLER_ROLE = 1 << 5;

    uint256 private number;

    function onInstall(bytes memory data) external virtual {}

    function onUninstall(bytes memory data) external virtual {}

    function getCallbacks() internal pure override returns (IModuleConfig.CallbackFunction[] memory functions) {
        functions = new IModuleConfig.CallbackFunction[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
        }
        functions[NUMBER_OF_CALLBACK].selector = this.callbackFunctionOne.selector;
    }

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](8);
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
        functions[6] =
            FallbackFunction({selector: bytes4(keccak256("setNumber(uint256)")), permissionBits: CALLER_ROLE});
        functions[7] = FallbackFunction({selector: bytes4(keccak256("getNumber()")), permissionBits: 0});
        config.fallbackFunctions = functions;

        config.registerInstallationCallback = true;
    }

    function setNumber(uint256 _number) external {
        number = _number;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function callbackFunctionOne() external virtual {
        emit CallbackFunctionOne();
    }

    function notPermissioned_call() external {
        emit FallbackFunctionCalled();
    }

    function notPermissioned_delegatecall() external {}

    function notPermissioned_staticcall() external view {}

    function permissioned_call() external {}

    function permissioned_delegatecall() external {}

    function permissioned_staticcall() external view {}

}

contract MockModuleReentrant is MockModuleWithFunctions {

    function callbackFunctionOne() external override {
        MockCore(payable(address(this))).callbackFunctionOne();
    }

}

contract MockModuleOnInstallFails is MockModuleWithFunctions {

    error OnInstallFailed();

    function onInstall(bytes memory data) external override {
        revert OnInstallFailed();
    }

}

contract MockModuleOnUninstallFails is MockModuleWithFunctions {

    error OnUninstallFailed();

    function onUninstall(bytes memory data) external override {
        revert OnUninstallFailed();
    }

}

contract MockModuleNoCallbacks is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new IModuleConfig.CallbackFunction[](0);

        FallbackFunction[] memory functions = new FallbackFunction[](1);
        functions[0] = FallbackFunction({selector: bytes4(keccak256("notPermissioned_call()")), permissionBits: 0});
    }

}

contract MockModuleNoFallbackFunctions is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }

}

contract MockModuleRequiresSomeInterface is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = bytes4(0x12345678);
    }

}

contract MockModuleOverlappingCallbacks is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }

}

contract MockModuleUnsupportedCallbacks is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new IModuleConfig.CallbackFunction[](1);
        config.callbackFunctions[0].selector = bytes4(0x12345678);
    }

}

contract MockModuleOverlappingFallbackFunction is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        FallbackFunction[] memory functions = new FallbackFunction[](1);
        functions[0] = FallbackFunction({selector: bytes4(keccak256("notPermissioned_call()")), permissionBits: 0});

        config.fallbackFunctions = functions;
    }

}

contract MockModuleAlternate is MockModuleWithFunctions {

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](9);
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
        functions[6] = FallbackFunction({selector: bytes4(keccak256("setNumber()")), permissionBits: CALLER_ROLE});
        functions[7] = FallbackFunction({selector: bytes4(keccak256("getNumber()")), permissionBits: 0});
        functions[8] = FallbackFunction({selector: bytes4(keccak256("someNewFunction()")), permissionBits: 0});
        config.fallbackFunctions = functions;
    }

    event SomeNewEvent();

    function someNewFunction() external {
        emit SomeNewEvent();
    }

}

contract CoreTest is Test {

    MockCore public core;

    MockModuleWithFunctions public module;
    MockModuleAlternate public alternateModule;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        core = new MockCore(owner);

        module = new MockModuleWithFunctions();
        alternateModule = new MockModuleAlternate();
    }

    /*//////////////////////////////////////////////////////////////
                        1. Install an module
    //////////////////////////////////////////////////////////////*/

    event CallbackFunctionOne();
    event FallbackFunctionCalled();

    function test_installModule() public {
        // 1. Install the module in the core contract by providing an implementation address.
        vm.prank(owner);
        core.installModule(address(module), "");

        // 2. Callback function is now called
        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // 3. Module functions now callable via the core contract fallback
        vm.expectEmit(true, false, false, false);
        emit FallbackFunctionCalled();
        MockModuleWithFunctions(address(core)).notPermissioned_call();
    }

    /*//////////////////////////////////////////////////////////////
                        2. Uninstall module
    //////////////////////////////////////////////////////////////*/

    function test_uninstallModule() public {
        // Setup: Install module in the core contract and set some storage
        vm.prank(owner);
        core.installModule(address(module), "");

        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // Uninstall the module from the core contract.

        vm.expectRevert(abi.encodeWithSelector(Core.ModuleNotInstalled.selector));
        vm.prank(owner);
        core.uninstallModule(address(alternateModule), "");

        vm.prank(owner);
        core.uninstallModule(address(module), "");

        // Required callback function no longer has a call destination
        vm.expectRevert(abi.encodeWithSelector(Core.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();
    }

    /*//////////////////////////////////////////////////////////////
                    Unit tests: installModule
    //////////////////////////////////////////////////////////////*/

    function test_installModule_state() public {
        // Check: no modules installed
        ICore.InstalledModule[] memory modulesBefore = core.getInstalledModules();
        assertEq(modulesBefore.length, 0);

        // Install module
        vm.prank(owner);
        core.installModule(address(module), "");

        // Now 1 module installed
        ICore.InstalledModule[] memory modulesAfter = core.getInstalledModules();
        assertEq(modulesAfter.length, 1);

        // Check module address

        assertEq(modulesAfter[0].implementation, address(module));

        // Check installed config matches config returned by module proxy
        IModuleConfig.ModuleConfig memory installedConfig = modulesAfter[0].config;
        IModuleConfig.ModuleConfig memory expectedConfig = Module(module).getModuleConfig();

        assertEq(installedConfig.requiredInterfaces.length, expectedConfig.requiredInterfaces.length);
        uint256 len = installedConfig.requiredInterfaces.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.requiredInterfaces[i], expectedConfig.requiredInterfaces[i]);
        }
        assertEq(installedConfig.registerInstallationCallback, expectedConfig.registerInstallationCallback);

        assertEq(installedConfig.supportedInterfaces.length, expectedConfig.supportedInterfaces.length);
        len = installedConfig.supportedInterfaces.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.supportedInterfaces[i], expectedConfig.supportedInterfaces[i]);
        }

        assertEq(installedConfig.callbackFunctions.length, expectedConfig.callbackFunctions.length);
        len = installedConfig.callbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.callbackFunctions[i].selector, expectedConfig.callbackFunctions[i].selector);
        }

        assertEq(installedConfig.fallbackFunctions.length, expectedConfig.fallbackFunctions.length);
        len = installedConfig.fallbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.fallbackFunctions[i].selector, expectedConfig.fallbackFunctions[i].selector);
            assertEq(
                installedConfig.fallbackFunctions[i].permissionBits, expectedConfig.fallbackFunctions[i].permissionBits
            );
        }

        // Check callback function is now callable
        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // Check fallback function is now callable
        vm.expectEmit(true, false, false, false);
        emit FallbackFunctionCalled();
        MockModuleWithFunctions(address(core)).notPermissioned_call();
    }

    function test_installModule_revert_reentrantCallbackFunction() public {
        MockModuleReentrant ext = new MockModuleReentrant();

        // Install module
        vm.prank(owner);
        core.installModule(address(ext), "");

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.Reentrancy.selector));
        core.callbackFunctionOne();
    }

    function test_installModule_revert_unauthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // OwnableRoles.Unauthorized()
        vm.prank(unpermissionedActor);
        core.installModule(address(module), "");
    }

    function test_installModule_revert_moduleAlreadyInstalled() public {
        // Install module
        vm.prank(owner);
        core.installModule(address(module), "");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.ModuleAlreadyInstalled.selector));
        core.installModule(address(module), "");
    }

    function test_installModule_revert_onInstallCallbackFailed() public {
        // Deploy module
        MockModuleOnInstallFails ext = new MockModuleOnInstallFails();

        // Install module
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MockModuleOnInstallFails.OnInstallFailed.selector));
        core.installModule(address(ext), "");
    }

    function test_installModule_revert_requiredInterfaceNotImplemented() public {
        // Deploy module
        MockModuleRequiresSomeInterface ext = new MockModuleRequiresSomeInterface();

        // Install module
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.ModuleInterfaceNotCompatible.selector, bytes4(0x12345678)));
        core.installModule(address(ext), "");
    }

    function test_installModule_revert_callbackFunctionAlreadyInstalled() public {
        // Install module
        vm.prank(owner);
        core.installModule(address(module), "");

        // Deploy conflicting module
        MockModuleOverlappingCallbacks ext = new MockModuleOverlappingCallbacks();

        // Install conflicting module
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.CallbackFunctionAlreadyInstalled.selector));
        core.installModule(address(ext), "");
    }

    function test_installModule_revert_callbackFunctionNotSupported() public {
        // Deploy module
        MockModuleUnsupportedCallbacks ext = new MockModuleUnsupportedCallbacks();

        // Install module
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.CallbackFunctionNotSupported.selector));
        core.installModule(address(ext), "");
    }

    function test_installModule_revert_fallbackFunctionAlreadyInstalled() public {
        // Install module
        vm.prank(owner);
        core.installModule(address(module), "");

        // Deploy conflicting module
        MockModuleOverlappingFallbackFunction ext = new MockModuleOverlappingFallbackFunction();

        // Install conflicting module
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.FallbackFunctionAlreadyInstalled.selector));
        core.installModule(address(ext), "");
    }

    /*//////////////////////////////////////////////////////////////
                    Unit tests: uninstallModule
    //////////////////////////////////////////////////////////////*/

    function test_uninstallModule_state() public {
        // Install module
        vm.prank(owner);
        core.installModule(address(module), "");

        ICore.InstalledModule[] memory modulesBefore = core.getInstalledModules();
        assertEq(modulesBefore.length, 1);

        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // Uninstall module
        vm.prank(owner);
        core.uninstallModule(address(module), "");

        // Check no modules installed
        ICore.InstalledModule[] memory modulesAfter = core.getInstalledModules();
        assertEq(modulesAfter.length, 0);

        // No callback function installed
        vm.expectRevert(abi.encodeWithSelector(Core.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();

        // No fallback function installed
        vm.expectRevert(abi.encodeWithSelector(Core.FallbackFunctionNotInstalled.selector));
        MockModuleWithFunctions(address(core)).notPermissioned_call();
    }

    function test_uninstallModule_revert_unauthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // OwnableRoles.Unauthorized()
        vm.prank(unpermissionedActor);
        core.uninstallModule(address(module), "");
    }

    function test_uninstallModule_revert_moduleNotInstalled() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Core.ModuleNotInstalled.selector));
        core.uninstallModule(address(module), "");
    }

    function test_uninstallModule_doesNotCauseRevert() public {
        // Deploy module
        MockModuleOnUninstallFails ext = new MockModuleOnUninstallFails();

        // Install module
        vm.prank(owner);
        core.installModule(address(ext), "");

        // Uninstall module
        vm.prank(owner);
        core.uninstallModule(address(ext), "");
    }

}
