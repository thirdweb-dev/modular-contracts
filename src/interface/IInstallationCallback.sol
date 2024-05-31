// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

interface IInstallationCallback {
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Called by a Core into an Extension during the installation of the Extension.
     *
     *  @param data The data passed to the Core's installExtension function.
     */
    function onInstall(bytes calldata data) external;

    /**
     *  @dev Called by a Core into an Extension during the uninstallation of the Extension.
     *
     *  @param data The data passed to the Core's uninstallExtension function.
     */
    function onUninstall(bytes calldata data) external;
}
