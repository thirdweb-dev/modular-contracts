// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {TOKEN_TYPE_ERC721} from "@creator-token-standards/permit-c/Constants.sol";
import {ICreatorToken} from "@creator-token-standards/interfaces/ICreatorToken.sol";
import {ITransferValidatorSetTokenType} from "@creator-token-standards/interfaces/ITransferValidatorSetTokenType.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

/**
 * @title  CreatorToken
 * @notice Functionality to enable Limit Break's Creator Token Standard for ERC721, and allow the usage of a transfer validator.
 */
library CreatorTokenStorage {
    /// @custom:storage-location erc7201:creator.token
    bytes32 public constant CREATORTOKEN_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.creator")) - 1)) &
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

contract CreatorToken is ICreatorToken {
    /// @dev Store the transfer validator. The address(0) indicates that no transfer validator has been set.

    /// @notice Revert with an error if the transfer validator is not valid
    error InvalidTransferValidatorContract();

    /*//////////////////////////////////////////////////////////////
                               EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig()
        external
        pure
        virtual
        override
        returns (ExtensionConfig memory config)
    {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.callbackFunctions[0] = CallbackFunction(
            this.beforeTransferERC721.selector
        );

        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.getTransferValidationFunction.selector,
            permissionBits: 0
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setTransferValidator.selector,
            permissionBits: Role._MANAGER_ROLE
        });

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.supportedInterfaces = new bytes4[](2);
        config.supportedInterfaces[0] = 0xad0d7f6c; // ICreatorToken
        config.supportedInterfaces[1] = 0xa07d229a; // ICreatorTokenLegacy

        config.registerInstallationCallback = true;
    }

    /// @dev Called by a Core into an Extension during the installation of the Extension.
    function onInstall(bytes calldata data) external {
        address validator = abi.decode(data, (address));
        _creatorTokenStorage().transferValidator = validator;
    }

    /// @dev Called by a Core into an Extension during the uninstallation of the Extension.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                               CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeTransfer hook, if installed.
    function beforeTransferERC721(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override returns (bytes memory) {
        address transferValidator = creatorTokenStorage().transferValidator;
        if (transferValidator != address(0)) {
            ITransferValidator(transferValidator).validateTransfer(
                msg.sender,
                from,
                to,
                tokenId
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction()
        external
        pure
        returns (bytes4 functionSignature, bool isViewFunction)
    {
        functionSignature = bytes4(
            keccak256(
                "validateTransfer(address,address,address,uint256,uint256)"
            )
        );
        isViewFunction = true;
    }

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view returns (address validator) {
        return _creatorTokenStorage().transferValidator;
    }

    function setTransferValidator(address validator) external {
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

    /*//////////////////////////////////////////////////////////////
                               INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // this function works since address(this) will be the core ERC721 contract
    // since this will be called via delegateCall
    //
    // setTokenTypeOfCollection checks if the ERC721 contract itself is the caller
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

    function _tokenType() internal pure virtual returns (uint16) {
        return uint16(TOKEN_TYPE_ERC1155);
    }

    function _creatorTokenStorage()
        internal
        pure
        returns (CreatorTokenStorage.Data storage)
    {
        return CreatorTokenStorage.data();
    }
}

