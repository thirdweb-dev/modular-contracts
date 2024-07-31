// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IInstallationCallback {

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Called by a Core into an Module during the installation of the Module.
     *
     *  @param data The data passed to the Core's installModule function.
     */
    function onInstall(bytes calldata data) external;

    /**
     *  @dev Called by a Core into an Module during the uninstallation of the Module.
     *
     *  @param data The data passed to the Core's uninstallModule function.
     */
    function onUninstall(bytes calldata data) external;

}
