pragma solidity ^0.8.20;

import {Role} from "../../../Role.sol";
import {Mint} from "./Mint.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";

contract SignatureMint is EIP712 {
    using ECDSA for bytes32;

    error SignatureMintRequestUnauthorizedSignature();
    error RequestMismatch();
    error RequestUidReused();

    function _signatureMintCheck(
        address _expectedRecipient,
        uint256 _expectedAmount,
        bool uidUsed,
        Mint.Params memory _params,
        Mint.Conditions memory _conditions
    ) internal {
        if (
            _params.signatureRequestRecipient != _expectedRecipient ||
            _conditions.quantity != _expectedAmount
        ) {
            revert RequestMismatch();
        }

        if (uidUsed) {
            revert RequestUidReused();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    Mint.TYPEHASH_SIGNATURE_MINT,
                    _conditions.startTimestamp,
                    _conditions.endTimestamp,
                    _params.signatureRequestRecipient,
                    _conditions.quantity,
                    _conditions.currency,
                    _conditions.pricePerUnit,
                    _params.signatureRequestUid
                )
            )
        ).recover(_params.signature);

        if (
            !OwnableRoles(address(this)).hasAllRoles(signer, Role._MINTER_ROLE)
        ) {
            revert SignatureMintRequestUnauthorizedSignature();
        }
    }

    function _signatureMintEffectsAndInteractions(
        Mint.Data storage data,
        bytes32 uid
    ) internal {
        data.uidUsed[uid] = true;
    }

    function _domainNameAndVersion()
        internal
        pure
        override
        returns (string memory name, string memory version)
    {
        name = "SignatureMint";
        version = "1";
    }
}
