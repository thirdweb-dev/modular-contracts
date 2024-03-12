// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "./IHook.sol";

interface IHookInstaller {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Parameters for installing a hook.
     *
     *  @param hook The hook to install.
     *  @param initCallValue The value to send with the initialization call.
     *  @param initCalldata The calldata to send with the initialization call.
     */
    struct InstallHookParams {
        IHook hook;
        uint256 initCallValue;
        bytes initCalldata;
    }

    /**
     *  @notice Parameters for any external call to make on initializing a core contract.
     *
     *  @param target The address of the contract to call.
     *  @param value The value to send with the call.
     *  @param data The calldata to send with the call.
     */
    struct OnInitializeParams {
        address target;
        uint256 value;
        bytes data;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is installed.
    event HooksInstalled(address indexed implementation, uint256 hooks);

    /// @notice Emitted when a hook is uninstalled.
    event HooksUninstalled(address indexed implementation, uint256 hooks);

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
     *  @param _params The parameters for installing the hook and initializing it with some data.
     */
    function installHook(InstallHookParams memory _params) external payable;

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param hook The hook to uninstall.
     */
    function uninstallHook(IHook hook) external;
}
