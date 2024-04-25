// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeApproveCallbackERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeApproveCallbackERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeApproveERC721 hook that is called by a core token before approving a token.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _tokenId The token ID being approved.
     *  @param _approve The approval status to set.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeApproveERC721(address _from, address _to, uint256 _tokenId, bool _approve)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeApproveCallbackERC721NotImplemented();
    }
}
