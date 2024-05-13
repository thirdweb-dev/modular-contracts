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

    /// @dev Struct for an extension function. Installing an extension in a core adds its extension functions to the core's ABI.
    struct FallbackFunction {
        bytes4 selector;
        CallType callType;
        uint256 permissionBits;
    }

    /// @notice All extension functions and supported callback functions of an extension contract.
    struct ExtensionConfig {
        bytes4 requiredInterfaceId; // Optional, can be bytes4(0), if there is no required interface id
        bool registerInstallationCallback; // Register onInstall / onUninstall callback
        bytes4[] callbackFunctions;
        bytes4[] supportedInterfaces;
        FallbackFunction[] fallbackFunctions;
    }
}
