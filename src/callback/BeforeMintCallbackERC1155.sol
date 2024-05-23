// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeMintCallbackERC1155 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintERC1155 hook that is called by a core token before minting tokens.
     *  @param _caller The address of the caller.
     *  @param _to The address that is minting tokens.
     *  @param _id The token ID being minted.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintERC1155(address _caller, address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeMintCallbackERC1155NotImplemented();
    }
}
