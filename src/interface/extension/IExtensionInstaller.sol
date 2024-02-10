// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtension} from "./IExtension.sol";

interface IExtensionInstaller {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a extension is installed.
    event ExtensionsInstalled(address indexed implementation, uint256 extensions);

    /// @notice Emitted when a extension is uninstalled.
    event ExtensionsUninstalled(address indexed implementation, uint256 extensions);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the caller is not authorized to install/uninstall extensions.
    error ExtensionsNotAuthorized();

    /// @notice Emitted when the caller attempts to install a extension that is already installed.
    error ExtensionsAlreadyInstalled();

    /// @notice Emitted when the caller attempts to uninstall a extension that is not installed.
    error ExtensionsNotInstalled();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Retusn the implementation of a given extension, if any.
     *  @param flag The bits representing the extension.
     *  @return impl The implementation of the extension.
     */
    function getExtensionImplementation(uint256 flag) external view returns (address impl);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a extension in the contract.
     *  @dev Maps all extension functions implemented by the extension to the extension's address.
     *  @param extension The extension to install.
     */
    function installExtension(IExtension extension) external;

    /**
     *  @notice Uninstalls a extension in the contract.
     *  @dev Reverts if the extension is not installed already.
     *  @param extension The extension to uninstall.
     */
    function uninstallExtension(IExtension extension) external;
}
