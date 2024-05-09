// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// Interface
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtension} from "./interface/IModularExtension.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";

// Utils
import {ModularExtension} from "./ModularExtension.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "@solady/utils/ERC1967FactoryConstants.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

abstract contract ModularCoreUpgradeable is IModularCore, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal representation of an extension function callable via fallback().
    struct InstalledExtensionFunction {
        address implementation;
        CallType callType;
        uint256 permissionBits;
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

    /// @dev The seed used to generate the next salt for extension proxies.
    bytes32 private extensionProxySaltSeed;

    /// @dev The set of extension IDs corresponding to installed extensions.
    EnumerableSetLib.Bytes32Set private extensionIDs;

    /// @dev extesion implementation => extension ID.
    mapping(address => bytes32) private extensionImplementationToID;

    /// @dev interface ID => counter of extensions supporting the interface.
    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;

    /// @dev callback function selector => call destination.
    mapping(bytes4 => address) private callbackFunctionImplementation_;

    /// @dev extension function selector => extension function data.
    mapping(bytes4 => InstalledExtensionFunction) private extensionFunctionData_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ExtensionOutOfSync();
    error ExtensionNotInstalled();
    error ExtensionAlreadyInstalled();

    error CallbackFunctionRequired();
    error CallbackExecutionReverted();
    error CallbackFunctionNotSupported();
    error CallbackFunctionAlreadyInstalled();

    error ExtensionFunctionAlreadyInstalled();
    error ExtensionFunctionNotInstalled();

    error ExtensionInterfaceNotCompatible(bytes4 requiredInterfaceId);

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /// @notice Routes a call to the appropriate extension contract.
    fallback() external payable {
        // Get extension function data.
        InstalledExtensionFunction memory extensionFunction = extensionFunctionData_[msg.sig];

        // Check: extension function data exists.
        if (extensionFunction.implementation == address(0)) {
            revert ExtensionFunctionNotInstalled();
        }

        // Check: authorized to call permissioned extension function
        if (extensionFunction.permissionBits > 0) {
            _checkOwnerOrRoles(extensionFunction.permissionBits);
        }

        // Call extension function.
        CallType callType = extensionFunction.callType;

        // note: these code block needs to happen at the end of the function
        if (callType == CallType.CALL) {
            _callAndReturn(extensionFunction.implementation);
        } else if (callType == CallType.DELEGATECALL) {
            _delegateAndReturn(extensionFunction.implementation);
        } else if (callType == CallType.STATICCALL) {
            _staticcallAndReturn(extensionFunction.implementation);
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

        ERC1967Factory proxyFactory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

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
        ERC1967Factory proxyFactory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
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
        _installExtension(_newExtensionImplementation, "");
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
        bytes32 extensionID = keccak256(abi.encode(extensionProxySaltSeed, address(this)));

        // Use the extension ID as a seed for whichever proxy contract contract is deployed next.
        extensionProxySaltSeed = extensionID;

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
        ERC1967Factory proxyFactory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
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
        ERC1967Factory proxyFactory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
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
            bytes4 callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (callbackFunctionImplementation_[callbackFunction] != address(0)) {
                revert CallbackFunctionAlreadyInstalled();
            }

            // Check: callback function is supported
            bool supported = false;
            for (uint256 j = 0; j < supportedCallbacksLength; j++) {
                if (supportedCallbacks[j].selector == callbackFunction) {
                    supported = true;
                    break;
                }
            }
            if (!supported) revert CallbackFunctionNotSupported();

            callbackFunctionImplementation_[callbackFunction] = _extensionProxyAddress;
        }

        // Store extension function data.
        uint256 functionLength = config.extensionFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionFunctions[i];

            // Check: extension function data not already stored.
            if (extensionFunctionData_[ext.selector].implementation != address(0)) {
                revert ExtensionFunctionAlreadyInstalled();
            }

            extensionFunctionData_[ext.selector] = InstalledExtensionFunction({
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

        uint256 functionLength = config.extensionFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionFunctions[i];
            delete extensionFunctionData_[ext.selector];
        }

        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionImplementation_[callbackFunction];
        }

        registeredInstallationCallback = config.registerInstallationCallback;
    }

    /// @dev Calls an extension callback function and checks whether it is optional or required.
    function _callExtensionCallback(bytes4 _selector, bytes memory _abiEncodedCalldata)
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

        address extension = callbackFunctionImplementation_[_selector];

        if (extension != address(0)) {
            (success, returndata) = extension.call{value: msg.value}(_abiEncodedCalldata);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        } else {
            if (callbackMode == CallbackMode.REQUIRED) {
                revert CallbackFunctionRequired();
            }
        }
    }

    /// @dev Staticcalls an extension callback function and checks whether it is optional or required.
    function _staticcallExtensionCallback(bytes4 _selector, bytes memory _abiEncodedCalldata)
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

        address extension = callbackFunctionImplementation_[_selector];

        if (extension != address(0)) {
            (success, returndata) = extension.staticcall(_abiEncodedCalldata);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
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
