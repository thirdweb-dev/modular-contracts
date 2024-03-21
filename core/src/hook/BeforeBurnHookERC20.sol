// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

abstract contract BeforeBurnHookERC20 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeBurnERC20 hook.
    uint256 public constant BEFORE_BURN_ERC20_FLAG = 2 ** 5;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBurnHookERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBurnERC20 hook that is called by a core token before burning tokens.
     *  @param _from The address that is burning tokens.
     *  @param _amount The amount of tokens being burned.
     *  @param _data The encoded arguments for the beforeBurn hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBurnERC20(address _from, uint256 _amount, bytes memory _data)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeBurnHookERC20NotImplemented();
    }
}
