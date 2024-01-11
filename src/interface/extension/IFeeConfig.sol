// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IFeeConfig {

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

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