// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { TokenHook } from "./TokenHook.sol";

abstract contract NFTHook is TokenHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_FLAG = 2 ** 6;
}