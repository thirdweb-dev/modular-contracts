// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBatchMintCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBatchMintCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBatchMintERC1155 hook that is called by a core token before minting tokens.
     *  @param to The address to mint the token to.
     *  @param ids The tokenIds to mint.
     *  @param amounts The amounts of tokens to mint.
     *  @param data ABI encoded data to pass to the beforeBatchMint hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBatchMintERC1155(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeBatchMintCallbackERC1155NotImplemented();
    }

}
