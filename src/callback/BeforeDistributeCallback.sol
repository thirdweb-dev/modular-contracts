// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Split} from "../libraries/Split.sol";

contract BeforeDistributeCallback {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeDistributeNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeDistribute hook that is called by a core split fees contract before distributing tokens.
     *  @dev Meant to be called by the core split fees contract.
     *  @param _splitWallet The address of the split wallet contract.
     *  @param _token The address of the token to distribute.
     *  @return amountToSplit The amount of tokens to distribute.
     */
    function beforeDistribute(address _splitWallet, address _token) external returns (uint256, Split memory) {
        revert BeforeDistributeNotImplemented();
    }

}
