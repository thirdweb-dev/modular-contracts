// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionConfig} from "./IExtensionConfig.sol";
import {IERC165} from "./IERC165.sol";

interface IModularCore is IExtensionConfig, IERC165 {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Whether execution reverts when the callback function is not implemented by any installed Extension.
     *  @param OPTIONAL Execution does not revert when the callback function is not implemented.
     *  @param REQUIRED Execution reverts when the callback function is not implemented.
     */
    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    /**
     *  @dev Struct representing a callback function called on an Extension during some fixed function's execution.
     *  @param selector The 4-byte function selector of the callback function.
     *  @param mode Whether execution reverts when the callback function is not implemented by any installed Extension.
     */
    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    /**
     *  @dev Struct representing an installed Extension.
     *  @param implementation The address of the Extension contract.
     *  @param config The Extension Config of the Extension contract.
     */
    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns all callback function calls made to Extensions at some point during a fixed function's execution.
    function getSupportedCallbackFunctions() external pure returns (SupportedCallbackFunction[] memory);

    /// @dev Returns all installed extensions and their respective extension configs.
    function getInstalledExtensions() external view returns (InstalledExtension[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Installs an Extension in the Core.
     *
     *  @param extensionContract The address of the Extension contract to be installed.
     *  @param data The data to be passed to the Extension's onInstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onInstall` callback function if Extension Config has registerd for installation callbacks.
     *  MUST revert if Core does not implement the interface required by the Extension, specified in the Extension Config.
     *  MUST revert if any callback or fallback function in the Extension's ExtensionConfig is already registered in the Core with another Extension.
     *
     *  MAY interpret the provided address as the implementation address of the Extension contract to install as a proxy.
     */
    function installExtension(address extensionContract, bytes calldata data) external payable;

    /**
     *  @dev Uninstalls an Extension from the Core.
     *
     *  @param extensionContract The address of the Extension contract to be uninstalled.
     *  @param data The data to be passed to the Extension's onUninstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onUninstall` callback function if Extension Config has registerd for installation callbacks.
     *
     *  MAY interpret the provided address as the implementation address of the Extension contract which is installed as a proxy.
     */
    function uninstallExtension(address extensionContract, bytes calldata data) external payable;
}
