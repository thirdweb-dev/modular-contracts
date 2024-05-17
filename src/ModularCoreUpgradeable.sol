// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// Interface
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtension} from "./interface/IModularExtension.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";

// Utils
import {ModularExtension} from "./ModularExtension.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

abstract contract ModularCoreUpgradeable is IModularCore, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal representation of an extension function callable via fallback().
    struct InstalledFallbackFunction {
        address implementation;
        CallType callType;
        uint256 permissionBits;
    }

    /// @dev Internal representation of a callback function called during the execution of some fixed function.
    struct InstalledCallbackFunction {
        address implementation;
        CallType callType;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an extension is installed.
    event ExtensionInstalled(address sender, address extensionImplementation, address extensionProxy);

    /// notice Emitted when an extension is updated.
    event ExtensionUpdated(
        address sender, address oldExtensionImplementation, address newExtensionImplementation, address extensionProxy
    );

    /// @notice Emitted when an extension is uninstalled.
    event ExtensionUninstalled(address sender, address extensionImplementation, address extensionProxy);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The role required to install or uninstall extensions.
    uint256 public constant INSTALLER_ROLE = _ROLE_0;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The address of the ERC1967Factory contract.
    address public immutable erc1967FactoryAddress;

    /// @dev The seed used to generate the next salt for extension proxies.
    uint256 private extensionProxySaltSeed;

    /// @dev The set of extension IDs corresponding to installed extensions.
    EnumerableSetLib.Bytes32Set private extensionIDs;

    /// @dev extesion implementation => extension ID.
    mapping(address => bytes32) private extensionImplementationToID;

    /// @dev interface ID => counter of extensions supporting the interface.
    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;

    /// @dev callback function selector => callback function data.
    mapping(bytes4 => InstalledCallbackFunction) private callbackFunctionData_;

    /// @dev extension function selector => extension function data.
    mapping(bytes4 => InstalledFallbackFunction) private fallbackFunctionData_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ExtensionNotInstalled();
    error ExtensionAlreadyInstalled();

    error CallbackFunctionRequired();
    error CallbackExecutionReverted();
    error CallbackFunctionNotSupported();
    error CallbackFunctionAlreadyInstalled();

    error FallbackFunctionAlreadyInstalled();
    error FallbackFunctionNotInstalled();

    error ExtensionInterfaceNotCompatible(bytes4 requiredInterfaceId);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _erc1967FactoryAddress) {
        erc1967FactoryAddress = _erc1967FactoryAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /// @notice Routes a call to the appropriate extension contract.
    fallback() external payable {
        // Get extension function data.
        InstalledFallbackFunction memory fallbackFunction = fallbackFunctionData_[msg.sig];

        // Check: extension function data exists.
        if (fallbackFunction.implementation == address(0)) {
            revert FallbackFunctionNotInstalled();
        }

        // Check: authorized to call permissioned extension function
        if (fallbackFunction.permissionBits > 0) {
            _checkOwnerOrRoles(fallbackFunction.permissionBits);
        }

        // Call extension function.
        CallType callType = fallbackFunction.callType;

        // note: these code block needs to happen at the end of the function
        if (callType == CallType.CALL) {
            _callAndReturn(fallbackFunction.implementation);
        } else if (callType == CallType.DELEGATECALL) {
            _delegateAndReturn(fallbackFunction.implementation);
        } else if (callType == CallType.STATICCALL) {
            _staticcallAndReturn(fallbackFunction.implementation);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the list of all callback functions called on some extension contract.
    function getSupportedCallbackFunctions() public pure virtual returns (SupportedCallbackFunction[] memory);

    /// @notice Returns a list of addresess and respective extension configs of all installed extensions.
    function getInstalledExtensions() external view returns (InstalledExtension[] memory _installedExtensions) {
        uint256 totalInstalled = extensionIDs.length();
        _installedExtensions = new InstalledExtension[](totalInstalled);

        ERC1967Factory proxyFactory = ERC1967Factory(erc1967FactoryAddress);

        for (uint256 i = 0; i < totalInstalled; i++) {
            address implementation = proxyFactory.predictDeterministicAddress(extensionIDs.at(i));
            _installedExtensions[i] = InstalledExtension({
                implementation: implementation,
                config: IModularExtension(implementation).getExtensionConfig()
            });
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Installs an extension contract.
    function installExtension(address _extensionImplementation, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(INSTALLER_ROLE)
    {
        // Install extension.
        _installExtension(_extensionImplementation, _data);
    }

    /// @notice Uninstalls an extension contract.
    function uninstallExtension(address _extensionImplementation, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(INSTALLER_ROLE)
    {
        // Uninstall extension.
        _uninstallExtension(_extensionImplementation, _data);
    }

    /// @notice Returns whether a given interface is implemented by the contract.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        if (supportedInterfaceRefCounter[interfaceId] > 0) return true;
        return false;
    }

    /// @notice Updates an extension contract.
    function updateExtension(address _currentExtensionImplementation, address _newExtensionImplementation)
        external
        onlyOwnerOrRoles(INSTALLER_ROLE)
    {
        // Get extension ID.
        bytes32 extensionID = extensionImplementationToID[_currentExtensionImplementation];

        // Check: extension is installed.
        if (extensionID == bytes32(0)) {
            revert ExtensionNotInstalled();
        }

        // Map new extension implementation to extension ID.
        delete extensionImplementationToID[_currentExtensionImplementation];
        extensionImplementationToID[_newExtensionImplementation] = extensionID;

        // Get extension proxy address from extension ID.
        ERC1967Factory proxyFactory = ERC1967Factory(erc1967FactoryAddress);
        address extensionProxyAddress = proxyFactory.predictDeterministicAddress(extensionID);

        /**
         *  We sandwich the upgrade of the proxy's implementation between an uninstallation and re-installation
         *  of its extension config.
         *
         *  This is because an upgrade may include changes to the return values of getExtensionConfig, and the
         *  core contract's storage must be in sync with the extension's new extension config.
         */

        // Uninstall the extension config of the proxy pre-upgrade
        _unmapExtensionConfigFromProxy(extensionProxyAddress);

        // Upgrade extension proxy implementation.
        proxyFactory.upgrade(extensionProxyAddress, _newExtensionImplementation);

        // Re-install the extension config of the proxy post-upgrade
        _mapExtensionConfigToProxy(extensionProxyAddress);

        emit ExtensionUpdated(
            msg.sender, _currentExtensionImplementation, _newExtensionImplementation, extensionProxyAddress
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Installs an extension contract.
    function _installExtension(address _extensionImplementation, bytes memory _data) internal {
        /**
         *  Check: extension is not already installed.
         *
         *  An extension ID is the representation of an Extension currently installed in the contract.
         *
         *  If an implementation is mapped to an extension ID, this means that an extension proxy contract
         *  with the underlying implementation is already deployed, and installed in the contract.
         */
        if (extensionImplementationToID[_extensionImplementation] != bytes32(0)) {
            revert ExtensionAlreadyInstalled();
        }

        /**
         *  Generate an extension ID that is new and random for this specific core contract instance.
         *
         *  We use this extension ID as the salt for the deterministic deployment of the extension proxy contract.
         *
         *  We will continue to use this extension ID to identify the installed Extension construct across `n` number
         *  of implementation upgrades of its extension proxy contract.
         *
         *  We discard this extension ID once the Extension is uninstalled.
         */
        bytes32 saltHash = keccak256(abi.encode(++extensionProxySaltSeed, msg.sender));
        bytes20 addressBytes = bytes20(address(this));

        bytes32 extensionID = bytes32(addressBytes) | (saltHash & bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFF)));

        /**
         *  Map the extension implementation to the extension ID.
         *
         *  Note: "extension ID" is an internal construct of this smart contract to uniquely identify an Extension (as a construct).
         *
         *  From the perspective of an end user of this contract, they are providing an implementation address as an extension to
         *  install, and they will later provide a new implementation address to update their extension, or the existing
         *  implementation address to uninstall their extension.
         */
        extensionImplementationToID[_extensionImplementation] = extensionID;

        // Deploy a new extension proxy contract if one does not already exist.
        ERC1967Factory proxyFactory = ERC1967Factory(erc1967FactoryAddress);
        address extensionProxyAddress = proxyFactory.predictDeterministicAddress(extensionID);

        if (extensionProxyAddress.code.length == 0) {
            proxyFactory.deployDeterministic(_extensionImplementation, address(this), extensionID);
        }

        // Store the new extension ID. Conflicts are not possible since each new extension ID is derived from a hash of the previous ID.
        extensionIDs.add(extensionID);

        // Fetch extension config and map config functions to proxy as call destination.
        bool registeredInstallationCallback = _mapExtensionConfigToProxy(extensionProxyAddress);

        // Call `onInstall` callback function if extension has registered installation callback.
        if (registeredInstallationCallback) {
            (bool success, bytes memory returndata) = extensionProxyAddress.call{value: msg.value}(
                abi.encodeCall(IInstallationCallback.onInstall, (msg.sender, _data))
            );
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionInstalled(msg.sender, _extensionImplementation, extensionProxyAddress);
    }

    /// @notice Uninstalls an extension contract.
    function _uninstallExtension(address _extensionImplementation, bytes memory _data) internal {
        // Get extension ID.
        bytes32 extensionID = extensionImplementationToID[_extensionImplementation];

        // Check: extension is installed.
        if (extensionID == bytes32(0)) {
            revert ExtensionNotInstalled();
        }

        // Remove extension ID from storage.
        extensionIDs.remove(extensionID);

        // Remove map of extension implementation to extension ID.
        delete extensionImplementationToID[_extensionImplementation];

        // Get extension proxy address from extension ID.
        ERC1967Factory proxyFactory = ERC1967Factory(erc1967FactoryAddress);
        address extensionProxyAddress = proxyFactory.predictDeterministicAddress(extensionID);

        // Fetch extension config and delete association of its functions with an extension proxy.
        bool registeredInstallationCallback = _unmapExtensionConfigFromProxy(extensionProxyAddress);

        if (registeredInstallationCallback) {
            (bool success, bytes memory returndata) = extensionProxyAddress.call{value: msg.value}(
                abi.encodeCall(IInstallationCallback.onUninstall, (msg.sender, _data))
            );
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionUninstalled(msg.sender, _extensionImplementation, extensionProxyAddress);
    }

    /// @notice Fetches an extension config and associates its functions with an extension proxy.
    function _mapExtensionConfigToProxy(address _extensionProxyAddress)
        private
        returns (bool registeredInstallationCallback)
    {
        ExtensionConfig memory config = IModularExtension(_extensionProxyAddress).getExtensionConfig();

        // Check: ModularCore supports interface required by extension.
        if (config.requiredInterfaceId != bytes4(0)) {
            if (!supportsInterface(config.requiredInterfaceId)) {
                revert ExtensionInterfaceNotCompatible(config.requiredInterfaceId);
            }
        }

        // Store interface support inherited via extension installation.
        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] += 1;
        }

        // Store callback function data. Only install supported callback functions
        SupportedCallbackFunction[] memory supportedCallbacks = getSupportedCallbackFunctions();
        uint256 supportedCallbacksLength = supportedCallbacks.length;

        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            CallbackFunction memory callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (callbackFunctionData_[callbackFunction.selector].implementation != address(0)) {
                revert CallbackFunctionAlreadyInstalled();
            }

            // Check: callback function is supported
            bool supported = false;
            for (uint256 j = 0; j < supportedCallbacksLength; j++) {
                if (supportedCallbacks[j].selector == callbackFunction.selector) {
                    supported = true;
                    break;
                }
            }
            if (!supported) revert CallbackFunctionNotSupported();

            callbackFunctionData_[callbackFunction.selector] =
                InstalledCallbackFunction({implementation: _extensionProxyAddress, callType: callbackFunction.callType});
        }

        // Store extension function data.
        uint256 functionLength = config.fallbackFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            FallbackFunction memory ext = config.fallbackFunctions[i];

            // Check: extension function data not already stored.
            if (fallbackFunctionData_[ext.selector].implementation != address(0)) {
                revert FallbackFunctionAlreadyInstalled();
            }

            fallbackFunctionData_[ext.selector] = InstalledFallbackFunction({
                implementation: _extensionProxyAddress,
                callType: ext.callType,
                permissionBits: ext.permissionBits
            });
        }

        registeredInstallationCallback = config.registerInstallationCallback;
    }

    /// @notice Fetches an extension config and deletes association of its functions with an extension proxy.
    function _unmapExtensionConfigFromProxy(address _extensionProxyAddress)
        private
        returns (bool registeredInstallationCallback)
    {
        ExtensionConfig memory config = IModularExtension(_extensionProxyAddress).getExtensionConfig();

        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            // Note: This should not underflow because extension needs to be installed before uninstalling. getExtensionConfig should returns the same value during installation and uninstallation.
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] -= 1;
        }

        uint256 functionLength = config.fallbackFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            FallbackFunction memory ext = config.fallbackFunctions[i];
            delete fallbackFunctionData_[ext.selector];
        }

        // Remove callback function data
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            CallbackFunction memory callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionData_[callbackFunction.selector];
        }

        registeredInstallationCallback = config.registerInstallationCallback;
    }

    /// @dev Calls an extension callback function and checks whether it is optional or required.
    function _executeCallbackFunction(bytes4 _selector, bytes memory _abiEncodedCalldata)
        internal
        returns (bool success, bytes memory returndata)
    {
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;

        // TODO: optimize
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == _selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        InstalledCallbackFunction memory callbackFunction = callbackFunctionData_[_selector];

        if (callbackFunction.implementation != address(0)) {
            if (callbackFunction.callType == CallType.CALL) {
                (success, returndata) = callbackFunction.implementation.call{value: msg.value}(_abiEncodedCalldata);
            } else if (callbackFunction.callType == CallType.DELEGATECALL) {
                (success, returndata) = callbackFunction.implementation.delegatecall(_abiEncodedCalldata);
            } else if (callbackFunction.callType == CallType.STATICCALL) {
                (success, returndata) = callbackFunction.implementation.staticcall(_abiEncodedCalldata);
            }
        } else {
            if (callbackMode == CallbackMode.REQUIRED) {
                revert CallbackFunctionRequired();
            }
        }
    }

    /// @dev Calls an extension callback function and checks whether it is optional or required.
    function _executeCallbackFunctionView(bytes4 _selector, bytes memory _abiEncodedCalldata)
        internal
        view
        returns (bool success, bytes memory returndata)
    {
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;

        // TODO: optimize
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == _selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        InstalledCallbackFunction memory callbackFunction = callbackFunctionData_[_selector];

        if (callbackFunction.callType != CallType.STATICCALL) {
            revert CallbackFunctionNotSupported();
        }

        if (callbackFunction.implementation != address(0)) {
            (success, returndata) = callbackFunction.implementation.staticcall(_abiEncodedCalldata);
        } else {
            if (callbackMode == CallbackMode.REQUIRED) {
                revert CallbackFunctionRequired();
            }
        }
    }

    /// @dev delegateCalls an `implementation` smart contract.
    /// @notice Only use this at the end of the function as it reverts or returns the result
    function _delegateAndReturn(address _implementation) private {
        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    /// @notice Only use this at the end of the function as it reverts or returns the result
    function _callAndReturn(address _implementation) private {
        uint256 value = msg.value;

        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := call(gas(), _implementation, value, calldataPtr, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    /// @notice Only use this at the end of the function as it reverts or returns the result
    function _staticcallAndReturn(address _implementation) private view {
        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := staticcall(gas(), _implementation, 0, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory _returnData, bytes4 _errorSignature) internal pure {
        // Look for revert reason and bubble it up if present
        if (_returnData.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(0x20, _returnData), mload(_returnData))
            }
        } else {
            assembly {
                mstore(0x00, _errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }
}
