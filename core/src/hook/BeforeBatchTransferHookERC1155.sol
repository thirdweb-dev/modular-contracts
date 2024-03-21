// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBatchTransferHookERC1155 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeBatchTransferERC1155 hook.
    uint256 public constant BEFORE_BATCH_TRANSFER_ERC1155_FLAG = 2 ** 4;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBatchTransferHookERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBatchTransferERC1155 hook that is called by a core token before batch transferring tokens.
     *  @param from The address that is transferring tokens.
     *  @param to The address that is receiving tokens.
     *  @param ids The token IDs being transferred.
     *  @param values The quantities of tokens being transferred.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBatchTransferERC1155(address from, address to, uint256[] calldata ids, uint256[] calldata values)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeBatchTransferHookERC1155NotImplemented();
    }
}
