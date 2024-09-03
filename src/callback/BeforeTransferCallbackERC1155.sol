// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract BeforeTransferCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeTransferCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeTransferERC1155 hook that is called by a core token before transferring a token.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _id The token ID being transferred.
     *  @param _amount The amount of tokens being transferred.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeTransferERC1155(address _from, address _to, uint256 _id, uint256 _amount)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeTransferCallbackERC1155NotImplemented();
    }

}
