// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IFeeConfig {

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The config specifying fee distribution in token mint sales
     *  @param primarySaleRecipient The address to which the primary sale revenue is sent.
     *  @param platformFeeRecipient The address to which the platform fee is sent.
     *  @param platformFeeBps The basis points of the sale price that is taken as platform fee.
     */
    struct FeeConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeeConfigUpdate(address indexed token, FeeConfig feeConfig);
}