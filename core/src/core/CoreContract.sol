// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionContract} from "../interface/IExtensionContract.sol";
import "../interface/IExtensionTypes.sol";

interface IExtensionInstallation {
    function onInstall(bytes calldata data) external;

    function onUninstall(bytes calldata data) external;
}

abstract contract CoreContract is IExtensionTypes {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct CallbackFunction {
        bytes4 selector;
        uint8 maxOrder; // before, on, after
        uint8 executionType; // execution error / success behavior?
        uint8 required; // required to execute on the function? (mint)
    }

    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    struct InstalledExtensionFunction {
        address implementation;
        ExtensionFunction data;
    }

    event ExtensionInstalled(address extension);
    event ExtensionUninstalled(address extension);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address[] private extensionImplementation_;
    mapping(address => bool) private extensionInstalled_;
    mapping(bytes4 => address) private callbackFunctionImplementation_;
    mapping(bytes4 => InstalledExtensionFunction)
        private extensionFunctionData_;

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
    error CallbackExecutionReverted();

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    fallback() external payable {
        // Get extension function data.
        InstalledExtensionFunction
            memory extensionFunction = extensionFunctionData_[msg.sig];

        // Check: extension function data exists.
        if (extensionFunction.implementation == address(0)) {
            revert InvalidFunction();
        }

        // Check: authorized to call permissioned extension function
        if (
            extensionFunction.data.permissioned &&
            !_isAuthorizedToCallExtensionFunctions(msg.sender)
        ) {
            revert UnauthorizedFunctionCall();
        }

        // Call extension function.
        CallType callType = extensionFunction.data.callType;

        // note: these code block needs to happen at the end of the function
        if (callType == CallType.CALL) {
            _callAndReturn(extensionFunction.implementation, msg.value);
        } else if (callType == CallType.DELEGATECALL) {
            _delegateAndReturn(extensionFunction.implementation);
        } else if (callType == CallType.STATICCALL) {
            _staticcallAndReturn(extensionFunction.implementation);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSupportedCallbackFunctions()
        public
        pure
        virtual
        returns (bytes4[] memory);

    function getInstalledExtensions()
        external
        view
        returns (InstalledExtension[] memory _installedExtensions)
    {
        uint256 totalInstalled = extensionImplementation_.length;
        _installedExtensions = new InstalledExtension[](totalInstalled);

        for (uint256 i = 0; i < totalInstalled; i++) {
            address implementation = extensionImplementation_[i];
            _installedExtensions[i] = InstalledExtension({
                implementation: implementation,
                config: IExtensionContract(implementation).getExtensionConfig()
            });
        }
    }

    function getCallbackFunctionImplementation(bytes4 _selector)
        public
        view
        returns (address)
    {
        return callbackFunctionImplementation_[_selector];
    }

    function getExtensionFunctionData(bytes4 _selector)
        public
        view
        returns (InstalledExtensionFunction memory)
    {
        return extensionFunctionData_[_selector];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installExtension(address _extensionContract, bytes calldata _data)
        external
        payable
    {
        // Check: authorized to install extensions.
        if (!_isAuthorizedToInstallExtensions(msg.sender)) {
            revert UnauthorizedInstall();
        }

        // Install extension.
        _installExtension(_extensionContract, _data);
    }

    function uninstallExtension(
        address _extensionContract,
        bytes calldata _data
    ) external payable {
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

    function _isAuthorizedToInstallExtensions(address _target)
        internal
        view
        virtual
        returns (bool);

    function _isAuthorizedToCallExtensionFunctions(address _target)
        internal
        view
        virtual
        returns (bool);

    function _installExtension(address _extension, bytes memory data) internal {
        // Check: extension not already installed.
        if (extensionInstalled_[_extension]) {
            revert ExtensionAlreadyInstalled();
        }
        extensionInstalled_[_extension] = true;
        extensionImplementation_.push(_extension);

        // Get extension config.
        ExtensionConfig memory config = IExtensionContract(_extension)
            .getExtensionConfig();

        // Store callback function data. Only install supported callback functions
        uint256 totalCallbacks = config.callbackFunctions.length;
        bytes4[] memory supportedCallbacks = getSupportedCallbackFunctions();

        for (uint256 i = 0; i < totalCallbacks; i++) {
            bytes4 callbackFunction = config.callbackFunctions[i];

            // Check: callback function data not already stored.
            if (
                callbackFunctionImplementation_[callbackFunction] != address(0)
            ) {
                revert CallbackFunctionAlreadyInstalled();
            }

            bool supported = false;
            for (uint256 j = 0; j < supportedCallbacks.length; j++) {
                if (callbackFunction == supportedCallbacks[j]) {
                    supported = true;
                    break;
                }
            }
            if (!supported) {
                revert ExtensionUnsupportedCallbackFunction();
            }

            callbackFunctionImplementation_[callbackFunction] = _extension;
        }

        // Store extension function data.
        uint256 totalFunctions = config.extensionABI.length;
        for (uint256 i = 0; i < totalFunctions; i++) {
            ExtensionFunction memory ext = config.extensionABI[i];

            // Check: extension function data not already stored.
            if (
                extensionFunctionData_[ext.selector].implementation !=
                address(0)
            ) {
                revert ExtensionFunctionAlreadyInstalled();
            }

            extensionFunctionData_[ext.selector] = InstalledExtensionFunction({
                implementation: _extension,
                data: ext
            });
        }

        // callback (TODO: check if contract supports it)
        (bool success, bytes memory returndata) = _extension.call{
            value: msg.value
        }(abi.encodeCall(IExtensionInstallation.onInstall, (data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionInstalled(_extension);
    }

    function _uninstallExtension(address _extension, bytes memory data)
        internal
    {
        // Check: extension installed.
        if (!extensionInstalled_[_extension]) {
            revert ExtensionNotInstalled();
        }
        delete extensionInstalled_[_extension];

        // Get extension config.
        ExtensionConfig memory config = IExtensionContract(_extension)
            .getExtensionConfig();

        // Remove extension function data.
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
        (bool success, bytes memory returndata) = _extension.call{
            value: msg.value
        }(abi.encodeCall(IExtensionInstallation.onUninstall, (data)));
        if (!success) {
            _revert(returndata, CallbackExecutionReverted.selector);
        }

        emit ExtensionUninstalled(_extension);
    }

    function _callExtensionCallback(
        bytes4 selector,
        bytes memory encodedAbiCallData
    ) internal {
        address extension = callbackFunctionImplementation_[selector];

        if (extension != address(0)) {
            (bool success, bytes memory returndata) = extension.call{
                value: msg.value
            }(encodedAbiCallData);
            if (!success) {
                _revert(returndata, CallbackExecutionReverted.selector);
            }
        }
    }

    /// @dev delegateCalls an `implementation` smart contract.
    function _delegateAndReturn(address implementation) private {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    function _callAndReturn(address implementation, uint256 _value) private {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Staticcall the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(
                gas(),
                implementation,
                _value,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @dev calls an `implementation` smart contract and returns data.
    function _staticcallAndReturn(address implementation) private view {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Staticcall the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := staticcall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory _returndata, bytes4 _errorSignature)
        internal
        pure
    {
        // Look for revert reason and bubble it up if present
        if (_returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(_returndata)
                revert(add(32, _returndata), returndata_size)
            }
        } else {
            assembly {
                mstore(0x00, _errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }
}
