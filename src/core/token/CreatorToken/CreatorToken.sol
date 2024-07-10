// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICreatorToken} from "@limitbreak/creator-token-standards/interfaces/ICreatorToken.sol";
import {ITransferValidatorSetTokenType} from
    "@limitbreak/creator-token-standards/interfaces/ITransferValidatorSetTokenType.sol";

/**
 * @title  CreatorToken
 * @notice Functionality to enable Limit Break's Creator Token Standard for ERC721, and allow the usage of a transfer validator.
 */
abstract contract CreatorToken is ICreatorToken {
    /// @dev Store the transfer validator. The address(0) indicates that no transfer validator has been set.
    address internal transferValidator;

    /// @notice Revert with an error if the transfer validator is not valid
    error InvalidTransferValidatorContract();

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view returns (address validator) {
        return transferValidator;
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    function _setTransferValidator(address validator) internal {
        bool isValidTransferValidator = validator.code.length > 0;

        if (validator != address(0) && !isValidTransferValidator) {
            revert InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(address(getTransferValidator()), validator);

        transferValidator = validator;
        _registerTokenType(validator);
    }

    function _registerTokenType(address validator) internal {
        if (validator != address(0)) {
            uint256 validatorCodeSize;
            assembly {
                validatorCodeSize := extcodesize(validator)
            }
            if (validatorCodeSize > 0) {
                try ITransferValidatorSetTokenType(validator).setTokenTypeOfCollection(address(this), _tokenType()) {}
                    catch {}
            }
        }
    }

    function _tokenType() internal pure virtual returns (uint16 tokenType);
}
