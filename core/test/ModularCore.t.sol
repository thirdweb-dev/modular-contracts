// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// Test utils
import {Test} from "forge-std/Test.sol";
import {ExtensionProxyFactory} from "./utils/ExtensionProxyFactory.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";

contract MockBase {
    uint256 internal constant NUMBER_OF_CALLBACK = 10;

    function getFunctionSignature() internal pure virtual returns (bytes4[] memory functions) {
        functions = new bytes4[](NUMBER_OF_CALLBACK);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i] = bytes4(uint32(i));
        }
    }
}

contract MockCore is MockBase, ModularCore {
    constructor(address _owner) {
        _setOwner(_owner);
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

        ExtensionFunction[] memory functions = new ExtensionFunction[](6);
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
        config.extensionFunctions = functions;
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

        ExtensionFunction[] memory functions = new ExtensionFunction[](7);
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
            selector: bytes4(keccak256("someNewFunction()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
        config.extensionFunctions = functions;
    }

    event SomeNewEvent();

    function someNewFunction() external {
        emit SomeNewEvent();
    }
}

contract ModularCoreTest is Test {
    ExtensionProxyFactory public factory;

    MockCore public core;
    MockExtensionWithFunctions public extensionImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        factory = new ExtensionProxyFactory();
        core = new MockCore(owner);
        extensionImplementation = new MockExtensionWithFunctions();
    }

    /*//////////////////////////////////////////////////////////////
                        1. Install an extension
    //////////////////////////////////////////////////////////////*/

    event CallbackFunctionOne();
    event ExtensionFunctionCalled();

    function test_installExtension() public {
        // 1. Deterministic deploy a proxy to the extension implementation using the core
        //    contract owner address as salt.
        //
        //    This is to maintain the property that the core contract owner can use 1 extension
        //    contract for N core contracts.

        bytes32 salt = bytes32(abi.encode(owner));
        address extensionAddress = factory.deployDeterministic(address(extensionImplementation), owner, salt);

        // 2. Install the extension in the core contract
        vm.prank(owner);
        core.installExtension(extensionAddress, "");

        // 3. Callback function is now called
        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // 4. Extension functions now callable via the core contract fallback
        vm.expectEmit(true, false, false, false);
        emit ExtensionFunctionCalled();
        MockExtensionWithFunctions(address(core)).notPermissioned_call();
    }

    function _setup_postInstallExtension() internal returns (address extensionAddress) {
        // 1. Deterministic deploy proxy to extension implementation.
        bytes32 salt = bytes32(abi.encode(owner));
        extensionAddress = factory.deployDeterministic(address(extensionImplementation), owner, salt);

        // 2. Install extension in the core contract
        vm.prank(owner);
        core.installExtension(extensionAddress, "");
    }

    /*//////////////////////////////////////////////////////////////
                        2. Update extension
    //////////////////////////////////////////////////////////////*/

    event SomeNewEvent();

    function test_updateExtension() public {
        address extension = _setup_postInstallExtension();

        // 1. The extension update is going to include an additional extension function in
        //    the extension config called `someNewFunction`.
        //
        //    This function is unavailable prior to the update, but crucial for the extension
        //    to work according to spec.

        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionFunctionNotInstalled.selector));
        MockExtensionAlternate(address(core)).someNewFunction();

        // 2. Core contract owner updates the extension used by all their N core contracts at once
        //    by updating its implementation via the extension proxy factory.

        address newExtensionImplementation = address(new MockExtensionAlternate());
        vm.prank(owner);
        factory.upgrade(extension, newExtensionImplementation);

        // 3. Now any core contract using the extension requires a refresh
        //    since it is currently out-of-sync with the updated extension config.

        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionFunctionNotInstalled.selector));
        MockExtensionAlternate(address(core)).someNewFunction();

        vm.startPrank(owner);
        core.uninstallExtension(extension, "");
        core.installExtension(extension, "");
        vm.stopPrank();

        // 4. The new extension function is now callable.

        vm.expectEmit(true, false, false, false);
        emit SomeNewEvent();
        MockExtensionAlternate(address(core)).someNewFunction();
    }

    /*//////////////////////////////////////////////////////////////
                        3. Uninstall extension
    //////////////////////////////////////////////////////////////*/

    function test_uninstallExtension() public {
        address extension = _setup_postInstallExtension();

        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // 1. Uninstall the extension from the core contract
        vm.prank(owner);
        core.uninstallExtension(extension, "");

        // 2. E.g. required callback function no longer has a call destination
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();
    }
}
