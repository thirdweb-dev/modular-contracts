// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeTransferHookERC1155 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeTransferERC1155 hook.
    uint256 public constant BEFORE_TRANSFER_ERC1155_FLAG = 2 ** 13;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeTransferHookERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeTransferERC1155 hook that is called by a core token before transferring a token.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _id The token ID being transferred.
     *  @param _value The quantity of tokens being transferred.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeTransferERC1155(address _from, address _to, uint256 _id, uint256 _value)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeTransferHookERC1155NotImplemented();
    }
}
