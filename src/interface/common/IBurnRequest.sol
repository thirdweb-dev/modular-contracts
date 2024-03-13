// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IBurnRequest {
    /**
     *  @notice Represents a request to burn tokens on an ERC-721 core contract.
     *
     *  @param owner The address of the token owner.
     *  @param token The address of the token to be burned.
     *  @param tokenId The id of the token to be burned.
     *  @param quantity The quantity of tokens to be burned.
     *  @param pricePerToken The price per token.
     *  @param currency The address of the currency to be used for payment.
     *  @param allowlistProof The proof of the minter's inclusion in an allowlist, if any.
     *  @param signature The signature of the token contract admin authorizing minting of tokens.
     *  @param sigValidityStartTimestamp The timestamp from which the signature is valid.
     *  @param sigValidityEndTimestamp The timestamp until which the signature is valid.
     *  @param sigUid The unique id of the signature.
     *  @param auxData Additional data.
     */
    struct BurnRequest {
        address owner;
        address token;
        uint256 tokenId;
        uint256 quantity;
        bytes32[] allowlistProof;
        bytes signature;
        uint128 sigValidityStartTimestamp;
        uint128 sigValidityEndTimestamp;
        bytes32 sigUid;
        bytes auxData;
    }
}
