// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// Test utils
import {Test} from "forge-std/Test.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "@solady/utils/ERC1967FactoryConstants.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";

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

contract MockCore is MockBase, ModularCore {
    constructor(address _erc1967FactoryAddress, address _owner) ModularCore(_erc1967FactoryAddress) {
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

contract MockExtensionWithFunctions is MockBase, ModularExtension {
    event CallbackFunctionOne();
    event FallbackFunctionCalled();

    uint256 public constant CALLER_ROLE = 1 << 5;

    uint256 private number;

    function onInstall(address sender, bytes memory data) external virtual {}

    function onUninstall(address sender, bytes memory data) external virtual {}

    function getCallbacks() internal pure override returns (IExtensionConfig.CallbackFunction[] memory functions) {
        functions = new IExtensionConfig.CallbackFunction[](NUMBER_OF_CALLBACK + 1);
        for (uint256 i = 0; i < NUMBER_OF_CALLBACK; i++) {
            functions[i].selector = bytes4(uint32(i));
            functions[i].callType = IExtensionConfig.CallType.CALL;
        }
        functions[NUMBER_OF_CALLBACK].selector = this.callbackFunctionOne.selector;
        functions[NUMBER_OF_CALLBACK].callType = IExtensionConfig.CallType.CALL;
    }

    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](8);
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
        functions[6] = FallbackFunction({
            selector: bytes4(keccak256("setNumber(uint256)")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[7] = FallbackFunction({
            selector: bytes4(keccak256("getNumber()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions = functions;

        config.registerInstallationCallback = true;
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
        emit FallbackFunctionCalled();
    }

    function notPermissioned_delegatecall() external {}

    function notPermissioned_staticcall() external view {}

    function permissioned_call() external {}

    function permissioned_delegatecall() external {}

    function permissioned_staticcall() external view {}
}

contract MockExtensionOnInstallFails is MockExtensionWithFunctions {
    error OnInstallFailed();

    function onInstall(address sender, bytes memory data) external override {
        revert OnInstallFailed();
    }
}

contract MockExtensionOnUninstallFails is MockExtensionWithFunctions {
    error OnUninstallFailed();

    function onUninstall(address sender, bytes memory data) external override {
        revert OnUninstallFailed();
    }
}

contract MockExtensionNoCallbacks is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new IExtensionConfig.CallbackFunction[](0);

        FallbackFunction[] memory functions = new FallbackFunction[](1);
        functions[0] = FallbackFunction({
            selector: bytes4(keccak256("notPermissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });
    }
}

contract MockExtensionNoFallbackFunctions is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }
}

contract MockExtensionRequiresSomeInterface is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();

        config.requiredInterfaceId = bytes4(0x12345678);
    }
}

contract MockExtensionOverlappingCallbacks is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();
    }
}

contract MockExtensionUnsupportedCallbacks is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new IExtensionConfig.CallbackFunction[](1);
        config.callbackFunctions[0].selector = bytes4(0x12345678);
        config.callbackFunctions[0].callType = IExtensionConfig.CallType.CALL;
    }
}

contract MockExtensionOverlappingFallbackFunction is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        FallbackFunction[] memory functions = new FallbackFunction[](1);
        functions[0] = FallbackFunction({
            selector: bytes4(keccak256("notPermissioned_call()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: 0
        });

        config.fallbackFunctions = functions;
    }
}

contract MockExtensionAlternate is MockExtensionWithFunctions {
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = getCallbacks();

        FallbackFunction[] memory functions = new FallbackFunction[](9);
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
        functions[6] = FallbackFunction({
            selector: bytes4(keccak256("setNumber()")),
            callType: IExtensionConfig.CallType.CALL,
            permissionBits: CALLER_ROLE
        });
        functions[7] = FallbackFunction({
            selector: bytes4(keccak256("getNumber()")),
            callType: IExtensionConfig.CallType.STATICCALL,
            permissionBits: 0
        });
        functions[8] = FallbackFunction({
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

contract ModularCoreTest is Test {
    MockCore public core;

    MockExtensionWithFunctions public extensionImplementation;
    MockExtensionAlternate public newExtensionImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        // Deterministic, canonical ERC1967Factory contract
        vm.etch(ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE);

        core = new MockCore(ERC1967FactoryConstants.ADDRESS, owner);

        extensionImplementation = new MockExtensionWithFunctions();
        newExtensionImplementation = new MockExtensionAlternate();
    }

    /*//////////////////////////////////////////////////////////////
                        1. Install an extension
    //////////////////////////////////////////////////////////////*/

    event CallbackFunctionOne();
    event FallbackFunctionCalled();

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
        emit FallbackFunctionCalled();
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

        vm.expectRevert(abi.encodeWithSelector(ModularCore.FallbackFunctionNotInstalled.selector));
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

        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionNotInstalled.selector));
        vm.prank(owner);
        core.uninstallExtension(address(extensionImplementation), "");

        vm.prank(owner);
        core.uninstallExtension(address(newExtensionImplementation), "");

        // 2. E.g. required callback function no longer has a call destination
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();
    }

    /*//////////////////////////////////////////////////////////////
                    Unit tests: installExtension
    //////////////////////////////////////////////////////////////*/

    function test_installExtension_state() public {
        // Check: no extensions installed
        IModularCore.InstalledExtension[] memory extensionsBefore = core.getInstalledExtensions();
        assertEq(extensionsBefore.length, 0);

        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Now 1 extension installed
        IModularCore.InstalledExtension[] memory extensionsAfter = core.getInstalledExtensions();
        assertEq(extensionsAfter.length, 1);

        // Check underlying extension proxy address
        ERC1967Factory factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

        bytes32 saltHash = keccak256(abi.encode(1, owner));
        bytes20 addressBytes = bytes20(address(core));
        bytes32 extensionID = bytes32(addressBytes) | (saltHash & bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFF)));

        address predictedExtensionProxyAddress = factory.predictDeterministicAddress(extensionID);

        assertEq(extensionsAfter[0].implementation, predictedExtensionProxyAddress);

        // Check installed config matches config returned by extension proxy
        IExtensionConfig.ExtensionConfig memory installedConfig = extensionsAfter[0].config;
        IExtensionConfig.ExtensionConfig memory expectedConfig =
            ModularExtension(predictedExtensionProxyAddress).getExtensionConfig();

        assertEq(installedConfig.requiredInterfaceId, expectedConfig.requiredInterfaceId);
        assertEq(installedConfig.registerInstallationCallback, expectedConfig.registerInstallationCallback);

        assertEq(installedConfig.supportedInterfaces.length, expectedConfig.supportedInterfaces.length);
        uint256 len = installedConfig.supportedInterfaces.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.supportedInterfaces[i], expectedConfig.supportedInterfaces[i]);
        }

        assertEq(installedConfig.callbackFunctions.length, expectedConfig.callbackFunctions.length);
        len = installedConfig.callbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.callbackFunctions[i].selector, expectedConfig.callbackFunctions[i].selector);
            assertEq(
                uint256(installedConfig.callbackFunctions[i].callType),
                uint256(expectedConfig.callbackFunctions[i].callType)
            );
        }

        assertEq(installedConfig.fallbackFunctions.length, expectedConfig.fallbackFunctions.length);
        len = installedConfig.fallbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.fallbackFunctions[i].selector, expectedConfig.fallbackFunctions[i].selector);
            assertEq(
                uint256(installedConfig.fallbackFunctions[i].callType),
                uint256(expectedConfig.fallbackFunctions[i].callType)
            );
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
        MockExtensionWithFunctions(address(core)).notPermissioned_call();
    }

    function test_installExtension_revert_unauthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // OwnableRoles.Unauthorized()
        vm.prank(unpermissionedActor);
        core.installExtension(address(extensionImplementation), "");
    }

    function test_installExtension_revert_extensionAlreadyInstalled() public {
        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionAlreadyInstalled.selector));
        core.installExtension(address(extensionImplementation), "");
    }

    function test_installExtension_revert_onInstallCallbackFailed() public {
        // Deploy extension
        MockExtensionOnInstallFails ext = new MockExtensionOnInstallFails();

        // Install extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MockExtensionOnInstallFails.OnInstallFailed.selector));
        core.installExtension(address(ext), "");
    }

    function test_installExtension_revert_requiredInterfaceNotImplemented() public {
        // Deploy extension
        MockExtensionRequiresSomeInterface ext = new MockExtensionRequiresSomeInterface();

        // Install extension
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ModularCore.ExtensionInterfaceNotCompatible.selector, bytes4(0x12345678))
        );
        core.installExtension(address(ext), "");
    }

    function test_installExtension_revert_callbackFunctionAlreadyInstalled() public {
        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Deploy conflicting extension
        MockExtensionOverlappingCallbacks ext = new MockExtensionOverlappingCallbacks();

        // Install conflicting extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionAlreadyInstalled.selector));
        core.installExtension(address(ext), "");
    }

    function test_installExtension_revert_callbackFunctionNotSupported() public {
        // Deploy extension
        MockExtensionUnsupportedCallbacks ext = new MockExtensionUnsupportedCallbacks();

        // Install extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionNotSupported.selector));
        core.installExtension(address(ext), "");
    }

    function test_installExtension_revert_fallbackFunctionAlreadyInstalled() public {
        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Deploy conflicting extension
        MockExtensionOverlappingFallbackFunction ext = new MockExtensionOverlappingFallbackFunction();

        // Install conflicting extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.FallbackFunctionAlreadyInstalled.selector));
        core.installExtension(address(ext), "");
    }

    /*//////////////////////////////////////////////////////////////
                    Unit tests: uninstallExtension
    //////////////////////////////////////////////////////////////*/

    function test_uninstallExtension_state() public {
        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory extensionsBefore = core.getInstalledExtensions();
        assertEq(extensionsBefore.length, 1);

        vm.expectEmit(true, false, false, false);
        emit CallbackFunctionOne();
        core.callbackFunctionOne();

        // Uninstall extension
        vm.prank(owner);
        core.uninstallExtension(address(extensionImplementation), "");

        // Check no extensions installed
        IModularCore.InstalledExtension[] memory extensionsAfter = core.getInstalledExtensions();
        assertEq(extensionsAfter.length, 0);

        // No callback function installed
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionRequired.selector));
        core.callbackFunctionOne();

        // No fallback function installed
        vm.expectRevert(abi.encodeWithSelector(ModularCore.FallbackFunctionNotInstalled.selector));
        MockExtensionWithFunctions(address(core)).notPermissioned_call();
    }

    function test_uninstallExtension_revert_unauthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // OwnableRoles.Unauthorized()
        vm.prank(unpermissionedActor);
        core.uninstallExtension(address(extensionImplementation), "");
    }

    function test_uninstallExtension_revert_extensionNotInstalled() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionNotInstalled.selector));
        core.uninstallExtension(address(extensionImplementation), "");
    }

    function test_uninstallExtension_revert_onUninstallCallbackFailed() public {
        // Deploy extension
        MockExtensionOnUninstallFails ext = new MockExtensionOnUninstallFails();

        // Install extension
        vm.prank(owner);
        core.installExtension(address(ext), "");

        // Uninstall extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MockExtensionOnUninstallFails.OnUninstallFailed.selector));
        core.uninstallExtension(address(ext), "");
    }

    /*//////////////////////////////////////////////////////////////
                    Unit tests: updateExtension
    //////////////////////////////////////////////////////////////*/

    function test_updateExtension_state() public {
        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory extensionsBefore = core.getInstalledExtensions();
        assertEq(extensionsBefore.length, 1);

        ERC1967Factory factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

        bytes32 saltHash = keccak256(abi.encode(1, owner));
        bytes20 addressBytes = bytes20(address(core));
        bytes32 extensionID = bytes32(addressBytes) | (saltHash & bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFF)));

        address predictedExtensionProxyAddress = factory.predictDeterministicAddress(extensionID);

        assertEq(extensionsBefore[0].implementation, predictedExtensionProxyAddress);

        // Setup: Update extension implementation to include new function.
        vm.prank(owner);
        core.updateExtension(address(extensionImplementation), address(newExtensionImplementation));

        // Check still one extension installed
        IModularCore.InstalledExtension[] memory extensionsAfter = core.getInstalledExtensions();
        assertEq(extensionsAfter.length, 1);

        // Check underlying extension proxy address remains the same
        assertEq(extensionsAfter[0].implementation, predictedExtensionProxyAddress);

        // Check installed config matches config returned by extension proxy
        IExtensionConfig.ExtensionConfig memory installedConfig = extensionsAfter[0].config;
        IExtensionConfig.ExtensionConfig memory expectedConfig =
            ModularExtension(predictedExtensionProxyAddress).getExtensionConfig();

        assertEq(installedConfig.requiredInterfaceId, expectedConfig.requiredInterfaceId);
        assertEq(installedConfig.registerInstallationCallback, expectedConfig.registerInstallationCallback);

        assertEq(installedConfig.supportedInterfaces.length, expectedConfig.supportedInterfaces.length);
        uint256 len = installedConfig.supportedInterfaces.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.supportedInterfaces[i], expectedConfig.supportedInterfaces[i]);
        }

        assertEq(installedConfig.callbackFunctions.length, expectedConfig.callbackFunctions.length);
        len = installedConfig.callbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            assertEq(installedConfig.callbackFunctions[i].selector, expectedConfig.callbackFunctions[i].selector);
            assertEq(
                uint256(installedConfig.callbackFunctions[i].callType),
                uint256(expectedConfig.callbackFunctions[i].callType)
            );
        }

        assertEq(installedConfig.fallbackFunctions.length, expectedConfig.fallbackFunctions.length);

        bool includesSomeNewFunction = false;
        len = installedConfig.fallbackFunctions.length;
        for (uint256 i = 0; i < len; i++) {
            if (installedConfig.fallbackFunctions[i].selector == bytes4(keccak256("someNewFunction()"))) {
                includesSomeNewFunction = true;
            }
            assertEq(installedConfig.fallbackFunctions[i].selector, expectedConfig.fallbackFunctions[i].selector);
            assertEq(
                uint256(installedConfig.fallbackFunctions[i].callType),
                uint256(expectedConfig.fallbackFunctions[i].callType)
            );
            assertEq(
                installedConfig.fallbackFunctions[i].permissionBits, expectedConfig.fallbackFunctions[i].permissionBits
            );
        }
        assertTrue(includesSomeNewFunction);
    }

    function test_updateExtension_revert_unauthorizedCaller() public {
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // OwnableRoles.Unauthorized()
        vm.prank(unpermissionedActor);
        core.updateExtension(address(extensionImplementation), address(newExtensionImplementation));
    }

    function test_updateExtension_revert_extensionNotInstalled() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.ExtensionNotInstalled.selector));
        core.updateExtension(address(extensionImplementation), address(newExtensionImplementation));
    }

    function test_updateExtension_revert_requiredInterfaceNotImplemented() public {
        // Deploy extension
        MockExtensionRequiresSomeInterface ext = new MockExtensionRequiresSomeInterface();

        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Update extension
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ModularCore.ExtensionInterfaceNotCompatible.selector, bytes4(0x12345678))
        );
        core.updateExtension(address(extensionImplementation), address(ext));
    }

    function test_updateExtension_revert_callbackFunctionAlreadyInstalled() public {
        // Deploy extensions
        MockExtensionNoCallbacks extWithoutCallbacks = new MockExtensionNoCallbacks();
        MockExtensionOverlappingCallbacks extWithCallbacks = new MockExtensionOverlappingCallbacks();

        // Install extension
        vm.prank(owner);
        core.installExtension(address(extWithoutCallbacks), "");

        vm.prank(owner);
        core.installExtension(address(extWithCallbacks), "");

        assertEq(core.getInstalledExtensions().length, 2);

        // Update extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionAlreadyInstalled.selector));
        core.updateExtension(address(extWithoutCallbacks), address(extensionImplementation));
    }

    function test_updateExtension_revert_callbackFunctionNotSupported() public {
        // Deploy extension
        MockExtensionUnsupportedCallbacks ext = new MockExtensionUnsupportedCallbacks();

        // Install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Update extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.CallbackFunctionNotSupported.selector));
        core.updateExtension(address(extensionImplementation), address(ext));
    }

    function test_updateExtension_revert_fallbackFunctionAlreadyInstalled() public {
        // Deploy extensions
        MockExtensionNoFallbackFunctions extWithoutFallbacks = new MockExtensionNoFallbackFunctions();
        MockExtensionOverlappingFallbackFunction extWithFallbacks = new MockExtensionOverlappingFallbackFunction();

        // Install extension
        vm.prank(owner);
        core.installExtension(address(extWithoutFallbacks), "");

        vm.prank(owner);
        core.installExtension(address(extWithFallbacks), "");

        assertEq(core.getInstalledExtensions().length, 2);

        // Update extension
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCore.FallbackFunctionAlreadyInstalled.selector));
        core.updateExtension(address(extWithoutFallbacks), address(extensionImplementation));
    }
}
