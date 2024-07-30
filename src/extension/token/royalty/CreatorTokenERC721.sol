// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICreatorToken} from "@limitbreak/creator-token-standards/interfaces/ICreatorToken.sol";
import {ITransferValidatorSetTokenType} from "@limitbreak/creator-token-standards/interfaces/ITransferValidatorSetTokenType.sol";

/**
 * @title  CreatorToken
 * @notice Functionality to enable Limit Break's Creator Token Standard for ERC721, and allow the usage of a transfer validator.
 */
library CreatorTokenStorage {
    /// @custom:storage-location erc7201:creator.token
    bytes32 public constant CREATORTOKEN_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("creator.token")) - 1)) &
            ~bytes32(uint256(0xff));

    struct Data {
        // Store the transfer validator. The address(0) indicates that no transfer validator has been set.
        address transferValidator;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CREATORTOKEN_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

abstract contract CreatorToken is ICreatorToken {
    /// @dev Store the transfer validator. The address(0) indicates that no transfer validator has been set.

    /// @notice Revert with an error if the transfer validator is not valid
    error InvalidTransferValidatorContract();

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view returns (address validator) {
        return _creatorTokenStorage().transferValidator;
    }

    function _setTransferValidator(address validator) internal {
        bool isValidTransferValidator = validator.code.length > 0;

        if (validator != address(0) && !isValidTransferValidator) {
            revert InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(
            address(getTransferValidator()),
            validator
        );

        _creatorTokenStorage().transferValidator = validator;
        _registerTokenType(validator);
    }

    function _registerTokenType(address validator) internal {
        if (validator != address(0)) {
            uint256 validatorCodeSize;
            assembly {
                validatorCodeSize := extcodesize(validator)
            }
            if (validatorCodeSize > 0) {
                try
                    ITransferValidatorSetTokenType(validator)
                        .setTokenTypeOfCollection(address(this), _tokenType())
                {} catch {}
            }
        }
    }

    function _tokenType() internal pure virtual returns (uint16 tokenType);

    function _creatorTokenStorage()
        internal
        pure
        returns (CreatorTokenStorage.Data storage)
    {
        return CreatorTokenStorage.data();
    }
}

