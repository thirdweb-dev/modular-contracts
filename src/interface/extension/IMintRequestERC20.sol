// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

interface IMintRequestERC20 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The body of a request to mint tokens.
     *
     *  @param to The receiver of the tokens to mint.
     *  @param primarySaleRecipient The recipient of the minted token's primary sales proceeds.
     *  @param quantity The quantity of tokens to mint.
     *  @param pricePerToken The price to pay per quantity of tokens minted.
     *  @param currency The currency in which to pay the price per token minted.
     *  @param validityStartTimestamp The unix timestamp after which the payload is valid.
     *  @param validityEndTimestamp The unix timestamp at which the payload expires.
     *  @param uid A unique identifier for the payload.
     */
    struct MintRequestERC20 {
        address token;
        address to;
        uint256 quantity;
        uint256 price;
        address currency;
        uint128 validityStartTimestamp;
        uint128 validityEndTimestamp;
        bytes32 uid;
    }
}
