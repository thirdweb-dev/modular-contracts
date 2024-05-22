// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeMintCallbackERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintCallbackERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintERC721 hook that is called by a core token before minting tokens.
     *  @param _caller The address that calls the mint function.
     *  @param _to The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintERC721(address _caller, address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeMintCallbackERC721NotImplemented();
    }
}
