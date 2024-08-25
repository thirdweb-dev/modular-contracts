// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// Interface

import {ICore} from "./interface/ICore.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";
import {IModule} from "./interface/IModule.sol";

// Utils
import {Role} from "./Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";

abstract contract Core is ICore, OwnableRoles, ReentrancyGuard {

    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /// @dev The type of function callable on module contracts.
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

    /// @notice Emitted when an module is installed.
    event ModuleInstalled(address caller, address implementation, address installedModule);

    /// @notice Emitted when an module is uninstalled.
    event ModuleUninstalled(address caller, address implementation, address installedModule);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The set of addresses of installed modules.
    EnumerableSetLib.AddressSet private modules;

    /// @dev interface ID => counter of modules supporting the interface.
    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;

    /// @dev function selector => function data.
    mapping(bytes4 => InstalledFunction) private functionData_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ModuleOutOfSync();
    error ModuleNotInstalled();
    error ModuleAlreadyInstalled();

    error CallbackFunctionRequired();
    error CallbackExecutionReverted();
    error CallbackFunctionNotSupported();
    error CallbackFunctionAlreadyInstalled();
    error CallbackFunctionUnauthorizedCall();

    error FallbackFunctionAlreadyInstalled();
    error FallbackFunctionNotInstalled();

    error ModuleInterfaceNotCompatible(bytes4 requiredInterfaceId);

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Routes a call to the appropriate module contract.
    fallback() external payable {
        // Get module function data.
        InstalledFunction memory fn = functionData_[msg.sig];

        // Check: module function data exists.
        if (fn.implementation == address(0)) {
            revert FallbackFunctionNotInstalled();
        }

        // Check: authorized to call permissioned module function
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

    /// @notice Returns the list of all callback functions called on some module contract.
    function getSupportedCallbackFunctions() public pure virtual returns (SupportedCallbackFunction[] memory);

    /// @notice Returns a list of addresess and respective module configs of all installed modules.
    function getInstalledModules() external view returns (InstalledModule[] memory _installedModules) {
        uint256 totalInstalled = modules.length();
        _installedModules = new InstalledModule[](totalInstalled);

        for (uint256 i = 0; i < totalInstalled; i++) {
            address implementation = modules.at(i);
            _installedModules[i] =
                InstalledModule({implementation: implementation, config: IModule(implementation).getModuleConfig()});
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Installs an module contract.
    function installModule(address _module, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(Role._INSTALLER_ROLE)
    {
        // Install module.
        _installModule(_module, _data);
    }

    /// @notice Uninstalls an module contract.
    function uninstallModule(address _module, bytes calldata _data)
        external
        payable
        onlyOwnerOrRoles(Role._INSTALLER_ROLE)
    {
        // Uninstall module.
        _uninstallModule(_module, _data);
    }

    /// @notice Returns whether a given interface is implemented by the contract.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        if (interfaceId == 0xffffffff) {
            return false;
        }
        if (supportedInterfaceRefCounter[interfaceId] > 0) {
            return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether a given interface is implemented by the contract.
    function _supportsInterfaceViaModules(bytes4 interfaceId) internal view virtual returns (bool) {
        if (interfaceId == 0xffffffff) {
            return false;
        }
        if (supportedInterfaceRefCounter[interfaceId] > 0) {
            return true;
        }
        return false;
    }

    /// @dev Installs an module contract.
    function _installModule(address _module, bytes memory _data) internal {
        if (!modules.add(_module)) {
            revert ModuleAlreadyInstalled();
        }

        // Get module config.
        ModuleConfig memory config = IModule(_module).getModuleConfig();

        // Check: Core supports interface required by module.
        if (config.requiredInterfaces.length != 0) {
            for (uint256 i = 0; i < config.requiredInterfaces.length; i++) {
                if (!supportsInterface(config.requiredInterfaces[i])) {
                    revert ModuleInterfaceNotCompatible(config.requiredInterfaces[i]);
                }
            }
        }

        // Store interface support inherited via module installation.
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
            if (!supported) {
                revert CallbackFunctionNotSupported();
            }

            functionData_[callbackFunction.selector] =
                InstalledFunction({implementation: _module, permissionBits: 0, fnType: FunctionType.CALLBACK});
        }

        // Store module function data.
        uint256 functionLength = config.fallbackFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            FallbackFunction memory ext = config.fallbackFunctions[i];

            // Check: module function data not already stored.
            if (functionData_[ext.selector].implementation != address(0)) {
                revert FallbackFunctionAlreadyInstalled();
            }

            functionData_[ext.selector] = InstalledFunction({
                implementation: _module,
                permissionBits: ext.permissionBits,
                fnType: FunctionType.FALLBACK
            });
        }

        // Call `onInstall` callback function if module has registered installation callback.
        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                _module.delegatecall(abi.encodeCall(IInstallationCallback.onInstall, (_data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ModuleInstalled(msg.sender, _module, _module);
    }

    /// @notice Uninstalls an module contract.
    function _uninstallModule(address _module, bytes memory _data) internal {
        // Check: remove and check if the module is installed
        if (!modules.remove(_module)) {
            revert ModuleNotInstalled();
        }

        // Get module config.
        ModuleConfig memory config = IModule(_module).getModuleConfig();

        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            // Note: This should not underflow because module needs to be installed before uninstalling. getModuleConfig should returns the same value during installation and uninstallation.
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] -= 1;
        }

        // Remove module function data
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
            _module.delegatecall(abi.encodeCall(IInstallationCallback.onUninstall, (_data)));
        }

        emit ModuleUninstalled(msg.sender, _module, _module);
    }

    /// @dev Calls an module callback function and checks whether it is optional or required.
    function _executeCallbackFunction(bytes4 _selector, bytes memory _abiEncodedCalldata)
        internal
        nonReentrant
        returns (bool success, bytes memory returndata)
    {
        InstalledFunction memory callbackFunction = functionData_[_selector];

        // Verify that the function is a callback function
        if (callbackFunction.fnType != FunctionType.CALLBACK) {
            revert CallbackFunctionNotSupported();
        }

        if (callbackFunction.implementation != address(0)) {
            (success, returndata) = callbackFunction.implementation.delegatecall(_abiEncodedCalldata);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        } else {
            // Get callback mode -- required or not required.
            SupportedCallbackFunction[] memory functions = getSupportedCallbackFunctions();
            uint256 len = functions.length;

            for (uint256 i = 0; i < len; i++) {
                if (functions[i].selector == _selector) {
                    if (functions[i].mode == CallbackMode.REQUIRED) {
                        revert CallbackFunctionRequired();
                    }
                }
            }
        }
    }

    /// @dev Calls an module callback function and checks whether it is optional or required.
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
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        } else if (callbackMode == CallbackMode.REQUIRED) {
            revert CallbackFunctionRequired();
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
