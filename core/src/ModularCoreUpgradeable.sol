// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// Interface
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtension} from "./interface/IModularExtension.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";

// Utils
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

abstract contract ModularCore is IModularCore, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

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
    event ExtensionInstalled(address sender, address extension);

    /// @notice Emitted when an extension is uninstalled.
    event ExtensionUninstalled(address sender, address extension);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The role required to install or uninstall extensions.
    uint256 public constant INSTALLER_ROLE = _ROLE_0;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The set of addresses of installed extensions.
    EnumerableSetLib.AddressSet private extensions;

    /// @dev interface ID => counter of extensions supporting the interface.
    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;

    /// @dev callback function selector => call destination.
    mapping(bytes4 => address) private callbackFunctionImplementation_;

    /// @dev extension function selector => extension function data.
    mapping(bytes4 => InstalledExtensionFunction) private extensionFunctionData_;

    /// @dev extension => bytecodehash stored at installation time.
    mapping(address => bytes32) private extensionBytecodehash;

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

        // Verify that extension works according to the extension config stored for it.
        _verifyExtensionBytecodehash(extensionFunction.implementation);

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
        uint256 totalInstalled = extensions.length();
        _installedExtensions = new InstalledExtension[](totalInstalled);

        for (uint256 i = 0; i < totalInstalled; i++) {
            address implementation = extensions.at(i);
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
    function installExtension(address _extension, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(INSTALLER_ROLE)
    {
        // Install extension.
        _installExtension(_extension, _data);
    }

    /// @notice Uninstalls an extension contract.
    function uninstallExtension(address _extension, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(INSTALLER_ROLE)
    {
        // Uninstall extension.
        _uninstallExtension(_extension, _data);
    }

    /// @notice Returns whether a given interface is implemented by the contract.
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        if (supportedInterfaceRefCounter[interfaceId] > 0) return true;
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Installs an extension contract.
    function _installExtension(address _extension, bytes memory _data) internal {
        if (!extensions.add(_extension)) {
            revert ExtensionAlreadyInstalled();
        }

        // Store extension bytecodehash
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(_extension)
        }
        extensionBytecodehash[_extension] = bytecodeHash;

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(_extension).getExtensionConfig();

        // Check: ModularCore supports interface required by extension.
        if (config.requiredInterfaceId != bytes4(0)) {
            if (!this.supportsInterface(config.requiredInterfaceId)) {
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

            callbackFunctionImplementation_[callbackFunction] = _extension;
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
                implementation: _extension,
                callType: ext.callType,
                permissionBits: ext.permissionBits
            });
        }

        // Call `onInstall` callback function if extension has registered installation callback.
        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                _extension.call{value: msg.value}(abi.encodeCall(IInstallationCallback.onInstall, (msg.sender, _data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionInstalled(msg.sender, _extension);
    }

    /// @notice Uninstalls an extension contract.
    function _uninstallExtension(address _extension, bytes memory _data) internal {
        // Check: remove and check if the extension is installed
        if (!extensions.remove(_extension)) {
            revert ExtensionNotInstalled();
        }

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(_extension).getExtensionConfig();

        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            // Note: This should not underflow because extension needs to be installed before uninstalling. getExtensionConfig should returns the same value during installation and uninstallation.
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] -= 1;
        }

        // Remove extension function data
        uint256 functionLength = config.extensionFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionFunctions[i];
            delete extensionFunctionData_[ext.selector];
        }

        // Remove callback function data
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionImplementation_[callbackFunction];
        }

        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) = _extension.call{value: msg.value}(
                abi.encodeCall(IInstallationCallback.onUninstall, (msg.sender, _data))
            );
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionUninstalled(msg.sender, _extension);
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

        // Verify that extension works according to the extension config stored for it.
        _verifyExtensionBytecodehash(extension);

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

        // Verify that extension works according to the extension config stored for it.
        _verifyExtensionBytecodehash(extension);

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

    /// @dev Verifies that the bytecode of the extension has not changed.
    function _verifyExtensionBytecodehash(address _extension) internal view {
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(_extension)
        }

        if (extensionBytecodehash[_extension] != bytecodeHash) {
            revert ExtensionOutOfSync();
        }
    }
}
