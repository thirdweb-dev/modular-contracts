// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

interface IExtensionConfig {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @dev Enum for the type of call to be made to an extension function.
    enum CallType {
        CALL,
        STATICCALL,
        DELEGATECALL
    }

    /// @dev Struct for a callback function. Called by a Core into an Extension during the execution of some fixed function.
    struct CallbackFunction {
        bytes4 selector;
        CallType callType;
    }

    /// @dev Struct for a fallback function. Installing an extension in a core adds its fallback functions to the core's ABI.
    struct FallbackFunction {
        bytes4 selector;
        CallType callType;
        uint256 permissionBits;
    }

    /// @notice All fallback functions and callback functions of an extension contract.
    struct ExtensionConfig {
        bytes4 requiredInterfaceId; // Optional, can be bytes4(0), if there is no required interface id
        bool registerInstallationCallback; // Register onInstall / onUninstall callback
        bytes4[] supportedInterfaces;
        CallbackFunction[] callbackFunctions;
        FallbackFunction[] fallbackFunctions;
    }
}
