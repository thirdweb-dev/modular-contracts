pragma solidity ^0.8.20;

library Mint {
    bytes32 constant TYPEHASH_SIGNATURE_MINT =
        keccak256(
            "SignatureMintRequest(uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
        );

    struct Conditions {
        uint48 startTimestamp;
        uint48 endTimestamp;
        uint256 quantity;
        address currency;
        uint256 pricePerUnit;
    }

    struct Params {
        Conditions conditions;
        address signatureRequestRecipient;
        bytes32 signatureRequestUid;
        bytes signature;
        bytes32[] recipientAllowlistProof;
        bytes32 uid;
    }

    struct Data {
        // claim condition
        Conditions conditions;
        // UID => whether it has been used
        mapping(bytes32 => bool) uidUsed;
        // sale config: primary sale recipient, and platform fee recipient + BPS.
        address primarySaleRecipient;
        uint256 availableSupply;
        bytes32 allowListMerkleRoot;
        string auxData;
    }
}
