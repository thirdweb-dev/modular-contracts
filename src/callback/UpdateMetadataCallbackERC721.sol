// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract UpdateMetadataCallbackERC721 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UpdateMetadataCallbackERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintERC721 hook that is called by a core token before minting tokens.
     *
     *  @param _to The address that is minting tokens.
     *  @param _amount The amount of tokens to mint.
     *  @param _baseURI The URI to fetch token metadata from.
     *  @return result Abi encoded bytes result of the hook.
     */
    function updateMetadataERC721(address _to, uint256 _startTokenId, uint256 _amount, string calldata _baseURI)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert UpdateMetadataCallbackERC721NotImplemented();
    }

}
