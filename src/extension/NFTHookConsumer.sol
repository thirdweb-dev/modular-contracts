// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { TokenHookConsumer } from "./TokenHookConsumer.sol";

abstract contract NFTHookConsumer is TokenHookConsumer {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;
    uint256 public constant ROYALTY_FLAG = 2 ** 6;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _maxFlagIndex() internal pure override returns (uint8) {
        return 6;
    }
}