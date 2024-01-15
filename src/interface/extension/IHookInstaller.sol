// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "./IHook.sol";

interface IHookInstaller {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is installed.
    event HooksInstalled(address indexed implementation, uint256 hooks);

    /// @notice Emitted when a hook is uninstalled.
    event HooksUninstalled(address indexed implementation, uint256 hooks);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the caller is not authorized to install/uninstall hooks.
    error HookNotAuthorized();

    /// @notice Emitted when the caller attempts to install a hook that is already installed.
    error HookAlreadyInstalled();

    /// @notice Emitted when the caller attempts to uninstall a hook that is not installed.
    error HookIsNotInstalled();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Retusn the implementation of a given hook, if any.
     *  @param flag The bits representing the hook.
     *  @return impl The implementation of the hook.
     */
    function getHookImplementation(uint256 flag) external view returns (address impl);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param hook The hook to install.
     */
    function installHook(IHook hook) external;

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param hook The hook to uninstall.
     */
    function uninstallHook(IHook hook) external;
}
