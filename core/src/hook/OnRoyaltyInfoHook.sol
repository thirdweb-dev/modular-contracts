// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

abstract contract OnRoyaltyInfoHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the onRoyaltyInfo hook.
    uint256 public constant ON_ROYALTY_INFO_FLAG = 2 ** 14;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnRoyaltyInfoHookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the royalty recipient and amount for a given sale.
     *  @dev Meant to be called by a token contract.
     *  @param _tokenId The token ID of the NFT.
     *  @param _salePrice The sale price of the NFT.
     *  @return receiver The royalty recipient address.
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale.
     */
    function onRoyaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        revert OnRoyaltyInfoHookNotImplemented();
    }
}
