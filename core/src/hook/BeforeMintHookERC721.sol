// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

abstract contract BeforeMintHookERC721 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeMintERC721 hook.
    uint256 public constant BEFORE_MINT_ERC721_FLAG = 2 ** 9;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintHookERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintERC721 hook that is called by a core token before minting tokens.
     *  @param _to The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeMintHookERC721NotImplemented();
    }
}
