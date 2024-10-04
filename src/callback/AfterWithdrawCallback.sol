// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Split} from "../libraries/Split.sol";

contract AfterWithdrawCallback {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error AfterWithdrawNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The afterWithdraw hook that is called by a core split fees contract after withdrawing tokens.
     *  @dev Meant to be called by the core split fees contract.
     *  @param amountToWithdraw The amount of tokens to withdraw.
     *  @param account The address of the account to withdraw tokens to.
     *  @param _token The address of the token to withdraw.
     */
    function afterWithdraw(uint256 amountToWithdraw, address account, address _token) external virtual {
        revert AfterWithdrawNotImplemented();
    }

}
