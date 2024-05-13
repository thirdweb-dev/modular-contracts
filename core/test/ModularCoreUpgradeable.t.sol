// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// Test utils
import {Test} from "forge-std/Test.sol";
import {ERC1967FactoryConstants} from "@solady/utils/ERC1967FactoryConstants.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCoreUpgradeable} from "src/ModularCoreUpgradeable.sol";

contract MockBase {
    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getFunctionSignature() internal pure virtual returns (bytes4[] memory functions) {
        functions = new bytes4[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = bytes4(uint32(i));
        }
    }
}

contract MockCore is MockBase, ModularCoreUpgradeable {
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
        _callExtensionCallback(msg.sig, abi.encodeCall(this.callbackFunctionOne, ()));
    }
}

contract MockExtensionWithFunctions is MockBase, ModularExtension {
    event CallbackFunctionOne();
    event ExtensionFunctionCalled();

    uint256 public constant CALLER_ROLE = 1 << 5;

    uint256 private number;

    function onInstall(address sender, bytes memory data) external {}

    function onUninstall(address sender, bytes memory data) external {}

    function getFunctionSignature() internal pure override returns (bytes4[] memory functions) {
        functions = new bytes4[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = bytes4(uint32(i));
        }
        functions[NUMBER_OF_CALLBACK] = this.callbackFunctionOne.selector;
    }

    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getFunctionSignature();

        ExtensionFunction[] memory functions = new ExtensionFunction[](8);
        functions[0] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
        functions[1] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: 0
        });
        functions[2] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        functions[3] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[4] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: CALLER_ROLE
        });
        functions[5] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: CALLER_ROLE
        });
        functions[6] = ExtensionFunction({
            selector: bytes4(keccak256("setNumber(uint256)")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[7] = ExtensionFunction({
            selector: bytes4(keccak256("getNumber()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions = functions;
    }

    function setNumber(uint256 _number) external {
        number = _number;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function callbackFunctionOne() external {
        emit CallbackFunctionOne();
    }

    function notPermissioned_call() external {
        emit ExtensionFunctionCalled();
    }

    function notPermissioned_delegatecall() external {}

    function notPermissioned_staticcall() external view {}

    function permissioned_call() external {}

    function permissioned_delegatecall() external {}

    function permissioned_staticcall() external view {}
}

contract MockExtensionAlternate is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getFunctionSignature();

        ExtensionFunction[] memory functions = new ExtensionFunction[](9);
        functions[0] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
        functions[1] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: 0
        });
        functions[2] = ExtensionFunction({
            selector: bytes4(keccak256("notPermissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        functions[3] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[4] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_delegatecall()")),
            callType: IExtensionConfig.CallType.DELEGATECALL,
            permissionBits: CALLER_ROLE
        });
        functions[5] = ExtensionFunction({
            selector: bytes4(keccak256("permissioned_staticcall()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: CALLER_ROLE
        });
        functions[6] = ExtensionFunction({
            selector: bytes4(keccak256("setNumber()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[7] = ExtensionFunction({
            selector: bytes4(keccak256("getNumber()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        functions[8] = ExtensionFunction({
            selector: bytes4(keccak256("someNewFunction()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
        config.fallbackFunctions = functions;
    }

    event SomeNewEvent();

    function someNewFunction() external {
        emit SomeNewEvent();
    }
}

contract ModularCoreUpgradeableTest is Test {
    MockCore public core;

    MockExtensionWithFunctions public extensionImplementation;
    MockExtensionAlternate public newExtensionImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        // Deterministic, canonical ERC1967Factory contract
        vm.etch(ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE);

        core = new MockCore(owner);

        extensionImplementation = new MockExtensionWithFunctions();
        newExtensionImplementation = new MockExtensionAlternate();
    }

    /*//////////////////////////////////////////////////////////////
                        1. Install an extension
    //////////////////////////////////////////////////////////////*/

    event CallbackFunctionOne();
    event ExtensionFunctionCalled();

    function test_installExtension() public {
        // 1. Install the extension in the core contract by providing an implementation address.
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // 2. Callback function is now called
        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // 3. Extension functions now callable via the core contract fallback
        vm.expectEmit(true, false, false, false);
        emit ExtensionFunctionCalled();
        MockExtensionWithFunctions(address(core)).notPermissioned_call();
    }

    /*//////////////////////////////////////////////////////////////
                        2. Update extension
    //////////////////////////////////////////////////////////////*/

    event SomeNewEvent();

    function test_updateExtension() public {
        // Setup: Install extension in the core contract and set some storage
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        vm.prank(owner);
        MockExtensionWithFunctions(address(core)).setNumber(42);
        assertEq(MockExtensionWithFunctions(address(core)).getNumber(), 42);

        // 1. The extension update is going to include an additional extension function in
        //    the extension config called `someNewFunction`.
        //
        //    This function is unavailable prior to the update, but crucial for the extension
        //    to work according to spec.

        vm.expectRevert(abi.encodeWithSelector(ModularCoreUpgradeable.ExtensionFunctionNotInstalled.selector));
        MockExtensionAlternate(address(core)).someNewFunction();

        // 2. Core contract owner updates the extension used by the core contract by updating
        //    its implementation via the `updateExtension` API.

        vm.prank(owner);
        core.updateExtension(address(extensionImplementation), address(newExtensionImplementation));

        // 3. The new extension function is now callable.

        vm.expectEmit(true, false, false, false);
        emit SomeNewEvent();
        MockExtensionAlternate(address(core)).someNewFunction();

        // 4. Storage is not lost during the update because the proxy contract is the same, only its implementation is now different.
        assertEq(MockExtensionAlternate(address(core)).getNumber(), 42);
    }

    /*//////////////////////////////////////////////////////////////
                        3. Uninstall extension
    //////////////////////////////////////////////////////////////*/

    function test_uninstallExtension() public {
        // Setup: Install extension in the core contract and set some storage
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Setup: Update extension implementation to include new function.
        vm.prank(owner);
        core.updateExtension(address(extensionImplementation), address(newExtensionImplementation));

        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // 1. Uninstall the extension from the core contract by providing the current implementation address.

        vm.expectRevert(abi.encodeWithSelector(ModularCoreUpgradeable.ExtensionNotInstalled.selector));
        vm.prank(owner);
        core.uninstallExtension(address(extensionImplementation), "");

        vm.prank(owner);
        core.uninstallExtension(address(newExtensionImplementation), "");

        // 2. E.g. required callback function no longer has a call destination
        vm.expectRevert(abi.encodeWithSelector(ModularCoreUpgradeable.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();
    }
}
