// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

interface IMintRequestERC721 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice A struct containing information about a mint request.
     *  @param token The address of the token to mint.
     *  @param to The address to which the minted tokens are sent.
     *  @param quantity The quantity of tokens to mint.
     *  @param pricePerToken The price per token in the sale.
     *  @param currency The currency in which the `pricePerToken` must be paid.
     *  @param validityStartTimestamp The unix timestamp after which the mint request is valid.
     *  @param validityEndTimestamp The unix timestamp at and after which the mint request is invalid.
     *  @param uid The unique identifier of the mint request.
     */
    struct MintRequestERC721 {
        address token;
        address to;
        uint256 quantity;
        uint256 pricePerToken;
        address currency;
        uint128 validityStartTimestamp;
        uint128 validityEndTimestamp;
        bytes32 uid;
    }
}
