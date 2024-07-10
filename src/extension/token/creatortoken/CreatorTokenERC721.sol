// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {BeforeTransferCallbackERC721} from "../../../callback/BeforeTransferCallbackERC721.sol";

import {ICreatorToken} from "@limitbreak/creator-token-standards/interfaces/ICreatorToken.sol";
import {ITransferValidatorSetTokenType} from
    "@limitbreak/creator-token-standards/interfaces/ITransferValidatorSetTokenType.sol";
import {TOKEN_TYPE_ERC721} from "@limitbreak/permit-c/Constants.sol";
import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";

library CreatorTokenStorage {
    /// @custom:storage-location erc7201:creator.token.erc721
    bytes32 public constant CREATORTOKEN_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("creator.token.erc721")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // the addresss of the transfer validator
        address transferValidator;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CREATORTOKEN_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract CreatorTokenERC721 is ModularExtension, BeforeTransferCallbackERC721, ICreatorToken {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Revert with an error if the transfer validator is not valid
    error InvalidTransferValidatorContract();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](3);

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC721.selector);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getTransferValidator.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.getTransferValidationFunction.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.setTransferValidator.selector, permissionBits: Role._MANAGER_ROLE});
        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721.transferFrom/safeTransferFrom
    function beforeTransferERC721(address from, address to, uint256 tokenId) external virtual override returns (bytes memory) {
        address transferValidator = getTransferValidator();
        if (transferValidator != address(0)) {
            ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, tokenId);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the transfer validator contract address for this token contract.
    function getTransferValidator() public view returns (address validator) {
        return _creatorTokenStorage().transferValidator;
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    function setTransferValidator(address validator) external {
        _setTransferValidator(validator);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setTransferValidator(address validator) internal {
        bool isValidTransferValidator = validator.code.length > 0;

        if (validator != address(0) && !isValidTransferValidator) {
            revert InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(address(getTransferValidator()), validator);

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
                try ITransferValidatorSetTokenType(validator).setTokenTypeOfCollection(address(this), _tokenType()) {}
                    catch {}
            }
        }
    }

    function _tokenType() internal pure virtual returns (uint16 tokenType) {
        return uint16(TOKEN_TYPE_ERC721);
    }

    function _creatorTokenStorage() internal pure returns (CreatorTokenStorage.Data storage) {
        return CreatorTokenStorage.data();
    }
}
