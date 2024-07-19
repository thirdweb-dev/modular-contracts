// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeMintCallbackERC20 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintCallbackERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintERC20 hook that is called by a core token before minting tokens.
     *
     *  @param _to The address to mint tokens to.
     *  @param _amount The amount of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintERC20(address _to, uint256 _amount, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeMintCallbackERC20NotImplemented();
    }

}
