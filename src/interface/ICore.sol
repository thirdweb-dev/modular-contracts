// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";
import {IModuleConfig} from "./IModuleConfig.sol";

interface ICore is IModuleConfig, IERC165 {

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Whether execution reverts when the callback function is not implemented by any installed Module.
     *  @param OPTIONAL Execution does not revert when the callback function is not implemented.
     *  @param REQUIRED Execution reverts when the callback function is not implemented.
     */
    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    /**
     *  @dev Struct representing a callback function called on an Module during some fixed function's execution.
     *  @param selector The 4-byte function selector of the callback function.
     *  @param mode Whether execution reverts when the callback function is not implemented by any installed Module.
     */
    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    /**
     *  @dev Struct representing an installed Module.
     *  @param implementation The address of the Module contract.
     *  @param config The Module Config of the Module contract.
     */
    struct InstalledModule {
        address implementation;
        ModuleConfig config;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns all callback function calls made to Modules at some point during a fixed function's execution.
    function getSupportedCallbackFunctions() external pure returns (SupportedCallbackFunction[] memory);

    /// @dev Returns all installed modules and their respective module configs.
    function getInstalledModules() external view returns (InstalledModule[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Installs an Module in the Core.
     *
     *  @param moduleContract The address of the Module contract to be installed.
     *  @param data The data to be passed to the Module's onInstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onInstall` callback function if Module Config has registerd for installation callbacks.
     *  MUST revert if Core does not implement the interface required by the Module, specified in the Module Config.
     *  MUST revert if any callback or fallback function in the Module's ModuleConfig is already registered in the Core with another Module.
     *
     *  MAY interpret the provided address as the implementation address of the Module contract to install as a proxy.
     */
    function installModule(address moduleContract, bytes calldata data) external payable;

    /**
     *  @dev Uninstalls an Module from the Core.
     *
     *  @param moduleContract The address of the Module contract to be uninstalled.
     *  @param data The data to be passed to the Module's onUninstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onUninstall` callback function if Module Config has registerd for installation callbacks.
     *
     *  MAY interpret the provided address as the implementation address of the Module contract which is installed as a proxy.
     */
    function uninstallModule(address moduleContract, bytes calldata data) external payable;

}
