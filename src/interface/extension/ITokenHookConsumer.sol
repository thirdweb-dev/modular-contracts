// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ITokenHook} from "./ITokenHook.sol";

interface ITokenHookConsumer {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementations of the token hooks.
    struct HookImplementation {
        address beforeMint;
        address beforeTransfer;
        address beforeBurn;
        address beforeApprove;
        address tokenUri;
        address royalty;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when the caller is not authorized to install/uninstall hooks.
    error TokenHookConsumerNotAuthorized();

    /// @notice Error emitted when the caller attempts to install a hook that is already installed.
    error TokenHookConsumerHookAlreadyExists();

    /// @notice Error emitted when the caller attempts to uninstall a hook that is not installed.
    error TokenHookConsumerHookDoesNotExist();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is installed.
    event TokenHookInstalled(address indexed implementation, uint256 hooks);

    /// @notice Emitted when a hook is uninstalled.
    event TokenHookUninstalled(address indexed implementation, uint256 hooks);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (HookImplementation memory hooks);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param hook The hook to install.
     */
    function installHook(ITokenHook hook) external;

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param hook The hook to uninstall.
     */
    function uninstallHook(ITokenHook hook) external;
}
