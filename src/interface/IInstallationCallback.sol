// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

interface IInstallationCallback {
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Called by a Core into an Extension during the installation of the Extension.
     *
     *  @param sender The address of the caller installing the Extension.
     *  @param data The data passed to the Core's installExtension function.
     */
    function onInstall(address sender, bytes calldata data) external;

    /**
     *  @dev Called by a Core into an Extension during the uninstallation of the Extension.
     *
     *  @param sender The address of the caller uninstalling the Extension.
     *  @param data The data passed to the Core's uninstallExtension function.
     */
    function onUninstall(address sender, bytes calldata data) external;
}
