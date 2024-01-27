// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHookInstaller} from "../extension/IHookInstaller.sol";

interface IERC1155HookInstaller is IHookInstaller {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementations of the token hooks.
    struct ERC1155Hooks {
        address beforeMint;
        address beforeTransfer;
        address beforeBurn;
        address beforeApprove;
        address uri;
        address royaltyInfo;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC1155Hooks memory hooks);
}
