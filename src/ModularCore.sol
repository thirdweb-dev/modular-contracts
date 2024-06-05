// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// Interface
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtension} from "./interface/IModularExtension.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";

// Utils
import {Role} from "./Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

abstract contract ModularCore is IModularCore, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /// @dev The type of function callable on extension contracts.
    enum FunctionType {
        CALLBACK,
        FALLBACK
    }

    /// @dev Internal representation of a fallback function callable via fallback().
    struct InstalledFunction {
        address implementation;
        uint256 permissionBits;
        FunctionType fnType;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an extension is installed.
    event ExtensionInstalled(address caller, address implementation, address installedExtension);

    /// @notice Emitted when an extension is uninstalled.
    event ExtensionUninstalled(address caller, address implementation, address installedExtension);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The set of addresses of installed extensions.
    EnumerableSetLib.AddressSet private extensions;

    /// @dev interface ID => counter of extensions supporting the interface.
    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;

    /// @dev function selector => function data.
    mapping(bytes4 => InstalledFunction) private functionData_;

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
    error CallbackFunctionUnauthorizedCall();

    error FallbackFunctionAlreadyInstalled();
    error FallbackFunctionNotInstalled();

    error ExtensionInterfaceNotCompatible(bytes4 requiredInterfaceId);

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /// @notice Routes a call to the appropriate extension contract.
    fallback() external payable {
        // Get extension function data.
        InstalledFunction memory fn = functionData_[msg.sig];

        // Check: extension function data exists.
        if (fn.implementation == address(0)) {
            revert FallbackFunctionNotInstalled();
        }

        // Check: authorized to call permissioned extension function
        if (fn.fnType == FunctionType.CALLBACK) {
            if (msg.sender != address(this)) {
                revert CallbackFunctionUnauthorizedCall();
            }
        } else if (fn.fnType == FunctionType.FALLBACK && fn.permissionBits > 0) {
            _checkOwnerOrRoles(fn.permissionBits);
        }

        _delegateAndReturn(fn.implementation);
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
        onlyOwnerOrRoles(Role._INSTALLER_ROLE)
    {
        // Install extension.
        _installExtension(_extension, _data);
    }

    /// @notice Uninstalls an extension contract.
    function uninstallExtension(address _extension, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(Role._INSTALLER_ROLE)
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

    /// @notice Returns whether a given interface is implemented by the contract.
    function _supportsInterfaceViaExtensions(bytes4 interfaceId) internal view virtual returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        if (supportedInterfaceRefCounter[interfaceId] > 0) return true;
        return false;
    }

    /// @dev Installs an extension contract.
    function _installExtension(address _extension, bytes memory _data) internal {
        if (!extensions.add(_extension)) {
            revert ExtensionAlreadyInstalled();
        }

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
            CallbackFunction memory callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (functionData_[callbackFunction.selector].implementation != address(0)) {
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

            functionData_[callbackFunction.selector] =
                InstalledFunction({implementation: _extension, permissionBits: 0, fnType: FunctionType.CALLBACK});
        }

        // Store extension function data.
        uint256 functionLength = config.fallbackFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            FallbackFunction memory ext = config.fallbackFunctions[i];

            // Check: extension function data not already stored.
            if (functionData_[ext.selector].implementation != address(0)) {
                revert FallbackFunctionAlreadyInstalled();
            }

            functionData_[ext.selector] = InstalledFunction({
                implementation: _extension,
                permissionBits: ext.permissionBits,
                fnType: FunctionType.FALLBACK
            });
        }

        // Call `onInstall` callback function if extension has registered installation callback.
        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                _extension.delegatecall(abi.encodeCall(IInstallationCallback.onInstall, (_data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionInstalled(msg.sender, _extension, _extension);
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
        uint256 functionLength = config.fallbackFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            delete functionData_[config.fallbackFunctions[i].selector];
        }

        // Remove callback function data
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            delete functionData_[config.callbackFunctions[i].selector];
        }

        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                _extension.delegatecall(abi.encodeCall(IInstallationCallback.onUninstall, (_data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionUninstalled(msg.sender, _extension, _extension);
    }

    /// @dev Calls an extension callback function and checks whether it is optional or required.
    function _executeCallbackFunction(bytes4 _selector, bytes memory _abiEncodedCalldata)
        internal
        returns (bool success, bytes memory returndata)
    {
        InstalledFunction memory callbackFunction = functionData_[_selector];

        // Verify that the function is a callback function
        if (callbackFunction.fnType != FunctionType.CALLBACK) {
            revert CallbackFunctionNotSupported();
        }

        // Get callback mode -- required or not required.
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == _selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        if (callbackFunction.implementation != address(0)) {
            (success, returndata) = callbackFunction.implementation.delegatecall(_abiEncodedCalldata);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        } else if (callbackMode == CallbackMode.REQUIRED) {
            revert CallbackFunctionRequired();
        }
    }

    /// @dev Calls an extension callback function and checks whether it is optional or required.
    function _executeCallbackFunctionView(bytes4 _selector, bytes memory _abiEncodedCalldata)
        internal
        view
        returns (bool success, bytes memory returndata)
    {
        InstalledFunction memory callbackFunction = functionData_[_selector];

        // Verify that the function is a callback function
        if (callbackFunction.fnType != FunctionType.CALLBACK) {
            revert CallbackFunctionNotSupported();
        }

        // Get callback mode -- required or not required.
        SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
        uint256 len = functions.length;

        CallbackMode callbackMode;
        for (uint256 i = 0; i < len; i++) {
            if (functions[i].selector == _selector) {
                callbackMode = functions[i].mode;
                break;
            }
        }

        if (callbackFunction.implementation != address(0)) {
            (success, returndata) = address(this).staticcall(_abiEncodedCalldata);
        } else {
            if (callbackMode == CallbackMode.REQUIRED) {
                revert CallbackFunctionRequired();
            }
        }
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
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

            let success := delegatecall(gas(), _implementation, calldataPtr, calldatasize(), 0, 0)

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
