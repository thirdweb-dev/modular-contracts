pragma solidity ^0.8.20;

import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {Mint} from "./Mint.sol";

library Allowlist {
    error NotInAllowlist();

    function _check(
        bytes32[] memory _allowlistProof,
        bytes32 _allowlistMerkleRoot,
        address _recipient
    ) internal view {
        bool isAllowlisted = MerkleProofLib.verify(
            _allowlistProof,
            _allowlistMerkleRoot,
            keccak256(abi.encodePacked(_recipient))
        );

        if (!isAllowlisted) {
            revert NotInAllowlist();
        }
    }
}
