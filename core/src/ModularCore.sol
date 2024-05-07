// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// Interface
import {IModularCore} from "./interface/IModularCore.sol";
import {IModularExtension} from "./interface/IModularExtension.sol";
import {IInstallationCallback} from "./interface/IInstallationCallback.sol";

// Utils
import {ExtensionProxy} from "./ExtensionProxy.sol";
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

    /// @notice Routes a call to the appropriate extension contract.
    fallback() external payable {
        // Get extension function data.
        InstalledExtensionFunction memory extensionFunction = extensionFunctionData_[msg.sig];

        // Check: extension function data exists.
        if (extensionFunction.implementation == address(0)) {
            revert InvalidFunction();
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
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        if (supportedInterfaceRefCounter[interfaceId] > 0) return true;
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Installs an extension contract.
    function _installExtension(address _extensionImplementation, bytes memory _data) internal {
        bytes32 salt = bytes32(keccak256(abi.encode(address(this), _extensionImplementation)));

        address extension = _predictExtensionProxyAddress(salt, _extensionImplementation);
        if (extension.code.length == 0) {
            new ExtensionProxy{salt: salt}(_extensionImplementation);
        }

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
        uint256 functionLength = config.extensionFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionFunctions[i];

            // Check: extension function data not already stored.
            if (extensionFunctionData_[ext.selector].implementation != address(0)) {
                revert ExtensionFunctionAlreadyInstalled();
            }

            extensionFunctionData_[ext.selector] = InstalledExtensionFunction({
                implementation: extension,
                callType: ext.callType,
                permissionBits: ext.permissionBits
            });
        }

        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                extension.call{value: msg.value}(abi.encodeCall(IInstallationCallback.onInstall, (msg.sender, _data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionInstalled(msg.sender, extension);
    }

    function _updateExtension(address _extension, bytes memory data) internal {
        // TODO
    }

    /// @notice Uninstalls an extension contract.
    function _uninstallExtension(address _extensionImplementation, bytes memory _data) internal {
        bytes32 salt = bytes32(keccak256(abi.encode(address(this), _extensionImplementation)));
        address extension = _predictExtensionProxyAddress(salt, _extensionImplementation);

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
        uint256 functionLength = config.extensionFunctions.length;
        for (uint256 i = 0; i < functionLength; i++) {
            ExtensionFunction memory ext = config.extensionFunctions[i];
            delete extensionFunctionData_[ext.selector];
        }

        // Remove callback function ext
        uint256 callbackLength = config.callbackFunctions.length;
        for (uint256 i = 0; i < callbackLength; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];
            delete callbackFunctionImplementation_[callbackFunction];
        }

        if (config.registerInstallationCallback) {
            (bool success, bytes memory returndata) =
                extension.call{value: msg.value}(abi.encodeCall(IInstallationCallback.onUninstall, (msg.sender, _data)));
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }

        emit ExtensionUninstalled(msg.sender, extension);
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

    /// @dev Returns the predicted address of an extension proxy contract.
    function _predictExtensionProxyAddress(bytes32 _salt, address _implementation) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            _salt,
                            keccak256(abi.encodePacked(type(ExtensionProxy).creationCode, abi.encode(_implementation)))
                        )
                    )
                )
            )
        );
    }
}
