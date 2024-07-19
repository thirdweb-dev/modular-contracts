// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

interface IExtensionConfig {

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Struct for a callback function. Called by a Core into an Extension during the execution of some fixed function.
     *
     *  @param selector The 4-byte selector of the function.
     *  @param callType The type of call to be made to the function.
     */
    struct CallbackFunction {
        bytes4 selector;
    }

    /**
     *  @dev Struct for a fallback function. Called by a Core into an Extension via the Core's fallback.
     *
     *  @param selector The 4-byte selector of the function.
     *  @param callType The type of call to be made to the function.
     *  @param permissionBits Core’s fallback function MUST check that msg.sender has these permissions before
     *                        performing a call on the Extension. (OPTIONAL field)
     */
    struct FallbackFunction {
        bytes4 selector;
        uint256 permissionBits;
    }

    /**
     *  @dev Struct containing all information that a Core uses to check whether an Extension is compatible for installation.
     *
     *  @param registerInstallationCallback Whether the Extension expects onInstall and onUninstall callback function calls at
     *                                      installation and uninstallation time, respectively
     *  @param requiredInterfaces The ERC-165 interface that a Core MUST support to be compatible for installation. OPTIONAL -- can be bytes4(0)
     *                             if there is no required interface id.
     *  @param supportedInterfaces The ERC-165 interfaces that a Core supports upon installing the Extension.
     *  @param callbackFunctions List of callback functions that the Core MUST call at some point in the execution of its fixed functions.
     *  @param fallbackFunctions List of functions that the Core MUST call via its fallback function with the Extension as the call destination.
     */
    struct ExtensionConfig {
        bool registerInstallationCallback;
        bytes4[] requiredInterfaces;
        bytes4[] supportedInterfaces;
        CallbackFunction[] callbackFunctions;
        FallbackFunction[] fallbackFunctions;
    }

}
