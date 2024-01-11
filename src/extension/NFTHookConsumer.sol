// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { TokenHookConsumer } from "./TokenHookConsumer.sol";

abstract contract NFTHookConsumer is TokenHookConsumer {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_FLAG = 2 ** 6;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the largest power of 2 that represents a hook.
    function _maxFlagIndex() internal pure override returns (uint8) {
        return 6;
    }
}