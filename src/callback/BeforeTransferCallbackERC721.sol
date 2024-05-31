// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeTransferCallbackERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeTransferCallbackERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeTransferERC721 hook that is called by a core token before transferring a token.
     *
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _tokenId The token ID being transferred.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeTransferERC721(address _from, address _to, uint256 _tokenId)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeTransferCallbackERC721NotImplemented();
    }
}
