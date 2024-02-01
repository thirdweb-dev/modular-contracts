// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IHookInstaller } from "./IHookInstaller.sol";

interface IERC20HookInstaller is IHookInstaller {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementations of the token hooks.
    struct ERC20Hooks {
        address beforeMint;
        address beforeTransfer;
        address beforeBurn;
        address beforeApprove;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC20Hooks memory hooks);
}
