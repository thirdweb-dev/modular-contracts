// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {ExtensionProxy} from "./ExtensionProxy.sol";
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtensionCallback, IModularExtension} from "./interface/IModularExtension.sol";
import {EnumerableSetLib} from "@solady/utils/EnumerableSetLib.sol";

abstract contract ModularCore is IModularCore {
    using EnumerableSetLib for *;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    event ExtensionInstalled(address sender, address extension);
    event ExtensionUninstalled(address sender, address extension);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    EnumerableSetLib.AddressSet private extensions;

    mapping(bytes4 => uint256) private supportedInterfaceRefCounter;
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
    error ExtensionInterfaceNotCompatible(bytes4 requiredInterfaceId);
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

    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        if (supportedInterfaceRefCounter[interfaceId] > 0) return true;
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isAuthorizedToInstallExtensions(address _target) internal view virtual returns (bool);

    function _isAuthorizedToCallExtensionFunctions(address _target) internal view virtual returns (bool);

    function _installExtension(address extensionImplementation, bytes memory data) internal {
        bytes32 salt = bytes32(keccak256(abi.encode(msg.sender, extensionImplementation))); // TODO

        // TODO: if create revert means plugin already deployed
        address extension = address(new ExtensionProxy{salt: salt}(extensionImplementation));

        // Check: add and check if extension not already installed.
        if (!extensions.add(extension)) {
            revert ExtensionAlreadyInstalled();
        }

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(extension).getExtensionConfig();

        if (config.requiredInterfaceId != bytes4(0)) {
            if (!this.supportsInterface(config.requiredInterfaceId)) {
                revert ExtensionInterfaceNotCompatible(config.requiredInterfaceId);
            }
        }

        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] += 1;
        }

        // Store callback function data. Only install supported callback functions
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (callbackFunctionImplementation_[callbackFunction] != address(0)) {
                revert CallbackFunctionAlreadyInstalled();
            }

            // extension can register to non-advertised callback functions, but they most likely won't be triggered

            callbackFunctionImplementation_[callbackFunction] = extension;
        }

        // Store extension function data.
        uint256 functionLength = config.extensionABI.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionABI[i];

            // Check: extension function data not already stored.
            if (extensionFunctionData_[ext.selector].implementation != address(0)) {
                revert ExtensionFunctionAlreadyInstalled();
            }

            extensionFunctionData_[ext.selector] = InstalledExtensionFunction({
                implementation: extension,
                callType: ext.callType,
                permission: ext.permissioned
            });
        }

        // callback (TODO: check if contract supports it)
        (bool success, bytes memory returndata) =
            extension.call{value: msg.value}(abi.encodeCall(IModularExtensionCallback.onInstall, (msg.sender, data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionInstalled(msg.sender, extension);
    }

    function _updateExtension(address _extension, bytes memory data) internal {
        // TODO
    }

    function _uninstallExtension(address extensionImplementation, bytes memory data) internal {
        bytes32 salt = bytes32(keccak256(abi.encode(msg.sender, extensionImplementation))); // TODO
        address extension = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(type(ExtensionProxy).creationCode, abi.encode(extensionImplementation))
                            )
                        )
                    )
                )
            )
        );

        // Check: remove and check if the extension is installed
        if (!extensions.remove(extension)) {
            revert ExtensionNotInstalled();
        }

        // Get extension config.
        ExtensionConfig memory config = IModularExtension(extension).getExtensionConfig();

        uint256 supportedInterfaceLength = config.supportedInterfaces.length;
        for (uint256 i = 0; i < supportedInterfaceLength; i++) {
            // Note: This should not underflow because extension needs to be installed before uninstalling. getExtensionConfig should returns the same value during installation and uninstallation.
            supportedInterfaceRefCounter[config.supportedInterfaces[i]] -= 1;
        }

        // Remove extension function data
        uint256 functionLength = config.extensionABI.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionABI[i];
            delete extensionFunctionData_[ext.selector];
        }

        // Remove callback function ext
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionImplementation_[callbackFunction];
        }

        // callback (TODO: check if contract supports it)
        (bool success, bytes memory returndata) =
            extension.call{value: msg.value}(abi.encodeCall(IModularExtensionCallback.onUninstall, (msg.sender, data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionUninstalled(msg.sender, extension);
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
