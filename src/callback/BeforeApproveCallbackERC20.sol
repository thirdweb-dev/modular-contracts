// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract BeforeApproveCallbackERC20 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeApproveCallbackERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeApproveERC20 hook that is called by a core token before approving tokens.
     *
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _amount The amount of tokens being approved.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeApproveERC20(address _from, address _to, uint256 _amount)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeApproveCallbackERC20NotImplemented();
    }

}
