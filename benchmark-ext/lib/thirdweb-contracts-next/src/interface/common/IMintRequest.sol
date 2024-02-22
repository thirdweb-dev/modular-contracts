// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IMintRequest {
    /**
     *  @notice Represents a mint request on a Mint Hook.
     *
     *  @param token The address of the token to be minted.
     *  @param tokenId The id of the token to be minted. Ingnored for ERC-20 and ERC-721 mint hooks.
     *  @param minter The address of the minter.
     *  @param quantity The quantity of tokens to be minted.
     *  @param pricePerToken The price per token.
     *  @param currency The address of the currency to be used for payment.
     *  @param allowlistProof The proof of the minter's inclusion in an allowlist, if any.
     *  @param permissionSignature The signature of the token contract admin authorizing minting of tokens.
     *  @param sigValidityStartTimestamp The timestamp from which the signature is valid.
     *  @param sigValidityEndTimestamp The timestamp until which the signature is valid.
     *  @param sigUid The unique id of the signature.
     */
    struct MintRequest {
        address token;
        uint256 tokenId;
        address minter;
        uint256 quantity;
        uint256 pricePerToken;
        address currency;
        bytes32[] allowlistProof;
        bytes permissionSignature;
        uint128 sigValidityStartTimestamp;
        uint128 sigValidityEndTimestamp;
        bytes32 sigUid;
    }
}
