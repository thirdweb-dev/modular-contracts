// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IModularExtension} from "../interface/IModularExtension.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

import "../interface/IExtensionTypes.sol";

interface IExtensionInstallation {
    function onInstall(bytes calldata data) external;

    function onUninstall(bytes calldata data) external;
}

abstract contract ModularCore is IExtensionTypes {
    using EnumerableSetLib for *;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    struct InstalledExtensionFunction {
        address implementation;
        CallType callType;
        bool permission;
    }

    event ExtensionInstalled(address extension);
    event ExtensionUninstalled(address extension);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    EnumerableSetLib.AddressSet private extensions;

    mapping(bytes4 => address) private callbackFunctionImplementation_;
    mapping(bytes4 => InstalledExtensionFunction) private extensionFunctionData_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnauthorizedInstall();
    error ExtensionUnsupportedCallbackFunction();
    error ExtensionInitializationFailed();
    error ExtensionAlreadyInstalled();
    error ExtensionNotInstalled();
    error InvalidFunction();
    error UnauthorizedFunctionCall();
    error ExtensionFunctionAlreadyInstalled();
    error CallbackFunctionAlreadyInstalled();
    error CallbackFunctionRequired();
    error CallbackExecutionReverted();

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    fallback() external payable {
        // Get extension function data.
        InstalledExtensionFunction memory extensionFunction = extensionFunctionData_[msg.sig];

        // Check: extension function data exists.
        if (extensionFunction.implementation == address(0)) {
            revert InvalidFunction();
        }

        // Check: authorized to call permissioned extension function
        if (extensionFunction.permission && !_isAuthorizedToCallExtensionFunctions(msg.sender)) {
            revert UnauthorizedFunctionCall();
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

    function getSupportedCallbackFunctions() public pure virtual returns (SupportedCallbackFunction[] memory);

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

    function installExtension(address _extensionContract, bytes calldata _data) external payable {
        // Check: authorized to install extensions.
        if (!_isAuthorizedToInstallExtensions(msg.sender)) {
            revert UnauthorizedInstall();
        }

        // Install extension.
        _installExtension(_extensionContract, _data);
    }

    function uninstallExtension(address _extensionContract, bytes calldata _data) external payable {
        // Check: authorized to install extensions.
        if (!_isAuthorizedToInstallExtensions(msg.sender)) {
            revert UnauthorizedInstall();
        }

        // Uninstall extension.
        _uninstallExtension(_extensionContract, _data);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isAuthorizedToInstallExtensions(address _target) internal view virtual returns (bool);

    function _isAuthorizedToCallExtensionFunctions(address _target) internal view virtual returns (bool);

    function _installExtension(address _extension, bytes memory data) internal {
        // Check: add and check if extension not already installed.
        if (!extensions.add(_extension)) {
            revert ExtensionAlreadyInstalled();
        }

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(_extension).getExtensionConfig();

        // Store callback function data. Only install supported callback functions
        uint256 totalCallbacks = config.callbackFunctions.length;
        for (uint256 i = 0; i < totalCallbacks; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (callbackFunctionImplementation_[callbackFunction] != address(0)) {
                revert CallbackFunctionAlreadyInstalled();
            }

            // extension can register to non-advertised callback functions, but they most likely won't be triggered

            callbackFunctionImplementation_[callbackFunction] = _extension;
        }

        // Store extension function data.
        uint256 totalFunctions = config.extensionABI.length;
        for (uint256 i = 0; i < totalFunctions; i++) {
            ExtensionFunction memory ext = config.extensionABI[i];

            // Check: extension function data not already stored.
            if (extensionFunctionData_[ext.selector].implementation != address(0)) {
                revert ExtensionFunctionAlreadyInstalled();
            }

            extensionFunctionData_[ext.selector] = InstalledExtensionFunction({
                implementation: _extension,
                callType: ext.callType,
                permission: ext.permissioned
            });
        }

        // callback (TODO: check if contract supports it)
        (bool success, bytes memory returndata) =
            _extension.call{value: msg.value}(abi.encodeCall(IExtensionInstallation.onInstall, (data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionInstalled(_extension);
    }

    function _uninstallExtension(address _extension, bytes memory data) internal {
        // Check: remove and check if the extension is installed
        if (!extensions.remove(_extension)) {
            revert ExtensionNotInstalled();
        }

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(_extension).getExtensionConfig();

        // Remove extension function data
        uint256 totalFunctions = config.extensionABI.length;
        for (uint256 i = 0; i < totalFunctions; i++) {
            ExtensionFunction memory ext = config.extensionABI[i];
            delete extensionFunctionData_[ext.selector];
        }

        // Remove callback function ext
        uint256 totalCallbacks = config.callbackFunctions.length;
        for (uint256 i = 0; i < totalCallbacks; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionImplementation_[callbackFunction];
        }

        // callback (TODO: check if contract supports it)
        (bool success, bytes memory returndata) =
            _extension.call{value: msg.value}(abi.encodeCall(IExtensionInstallation.onUninstall, (data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionUninstalled(_extension);
    }

    function _callExtensionCallback(bytes4 selector, bytes memory encodedAbiCallData)
        internal
        returns (bool success, bytes memory returndata)
    {
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;

        // TODO: optimize
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        address extension = callbackFunctionImplementation_[selector];
        if (extension != address(0)) {
            (success, returndata) = extension.call{value: msg.value}(encodedAbiCallData);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        } else {
            if (callbackMode == CallbackMode.REQUIRED) {
                revert CallbackFunctionRequired();
            }
        }
    }

    function _staticcallExtensionCallback(bytes4 selector, bytes memory encodedAbiCallData)
        internal
        view
        returns (bool success, bytes memory returndata)
    {
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;

        // TODO: optimize
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        address extension = callbackFunctionImplementation_[selector];
        if (extension != address(0)) {
            (success, returndata) = extension.staticcall(encodedAbiCallData);
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
    function _delegateAndReturn(address implementation) private {
        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    /// @notice Only use this at the end of the function as it reverts or returns the result
    function _callAndReturn(address implementation) private {
        uint256 value = msg.value;

        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := call(gas(), implementation, value, calldataPtr, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    /// @notice Only use this at the end of the function as it reverts or returns the result
    function _staticcallAndReturn(address implementation) private view {
        /// @solidity memory-safe-assembly
        assembly {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let success := staticcall(gas(), implementation, 0, calldatasize(), 0, 0)

            let returnDataPtr := allocate(returndatasize())
            returndatacopy(returnDataPtr, 0, returndatasize())
            if iszero(success) { revert(returnDataPtr, returndatasize()) }
            return(returnDataPtr, returndatasize())
        }
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory returnData, bytes4 errorSignature) internal pure {
        // Look for revert reason and bubble it up if present
        if (returnData.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(0x20, returnData), mload(returnData))
            }
        } else {
            assembly {
                mstore(0x00, errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }
}
