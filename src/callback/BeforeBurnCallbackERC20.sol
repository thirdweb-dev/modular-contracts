// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBurnCallbackERC20 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBurnCallbackERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBurnERC20 hook that is called by a core token before burning tokens.
     *
     *  @param _from The address whose tokens are being burned.
     *  @param _amount The amount of tokens being burned.
     *  @param _data The encoded arguments for the beforeBurn hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBurnERC20(address _from, uint256 _amount, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeBurnCallbackERC20NotImplemented();
    }
}
