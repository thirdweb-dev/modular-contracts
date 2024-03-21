// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

abstract contract BeforeTransferHookERC20 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeTransferERC20 hook.
    uint256 public constant BEFORE_TRANSFER_ERC20_FLAG = 2 ** 11;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeTransferHookERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeTransferERC20 hook that is called by a core token before transferring tokens.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _amount The amount of tokens being transferred.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeTransferERC20(address _from, address _to, uint256 _amount)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeTransferHookERC20NotImplemented();
    }
}
