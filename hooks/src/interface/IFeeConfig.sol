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

    /// @notice Emitted when the fee config is updated.
    event DefaultFeeConfigUpdate(address indexed token, FeeConfig feeConfig);

    /// @notice Emitted when the fee config is updated for a particular tokenId.
    event TokenFeeConfigUpdate(address indexed token, uint256 id, FeeConfig feeConfig);
}
