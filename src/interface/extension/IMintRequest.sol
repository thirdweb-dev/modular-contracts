// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IMintRequest {

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