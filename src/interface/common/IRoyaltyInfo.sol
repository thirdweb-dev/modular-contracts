// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IRoyaltyInfo {
    /**
     *  @notice The royalty info for a token.
     *  @param recipient The royalty recipient address.
     *  @param bps The basis points of the sale price that is taken as royalty.
     */
    struct RoyaltyInfo {
        address recipient;
        uint256 bps;
    }
}