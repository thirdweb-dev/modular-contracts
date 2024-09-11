// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

import {BeforeBatchTransferCallbackERC1155} from "../../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../../callback/BeforeTransferCallbackERC1155.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";

import {ICreatorToken} from "@limitbreak/creator-token-standards/interfaces/ICreatorToken.sol";

import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";
import {ITransferValidatorSetTokenType} from
    "@limitbreak/creator-token-standards/interfaces/ITransferValidatorSetTokenType.sol";
import {TOKEN_TYPE_ERC1155} from "@limitbreak/permit-c/Constants.sol";

library RoyaltyStorage {

    /// @custom:storage-location erc7201:token.royalty.ERC1155
    bytes32 public constant ROYALTY_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.royalty.erc1155")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // default royalty info
        RoyaltyERC1155.RoyaltyInfo defaultRoyaltyInfo;
        // tokenId => royalty info
        mapping(uint256 => RoyaltyERC1155.RoyaltyInfo) royaltyInfoForToken;
        // the addresss of the transfer validator
        address transferValidator;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ROYALTY_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract RoyaltyERC1155 is
    Module,
    IInstallationCallback,
    BeforeTransferCallbackERC1155,
    BeforeBatchTransferCallbackERC1155,
    ICreatorToken
{

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant DEFAULT_ACCESS_CONTROL_ADMIN_ROLE = 0x00;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *   @notice RoyaltyInfo struct to store royalty information.
     *   @param recipient The address that will receive the royalty payment.
     *   @param bps The percentage of a secondary sale that will be paid as royalty.
     */
    struct RoyaltyInfo {
        address recipient;
        uint16 bps;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the default royalty info for a token is updated.
    event DefaultRoyaltyUpdated(address indexed recipient, uint16 bps);

    /// @notice Emitted when the royalty info for a specific NFT is updated.
    event TokenRoyaltyUpdated(uint256 indexed tokenId, address indexed recipient, uint16 bps);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when royalty BPS exceeds 10,000.
    error RoyaltyExceedsMaxBps();

    /// @notice Revert with an error if the transfer validator is not valid
    error RoyaltyInvalidTransferValidatorContract();

    /// @notice Revert with an error if the transfer validator is not valid
    error RoyaltyNotTransferValidator();

    /*//////////////////////////////////////////////////////////////
                               MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](9);

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC1155.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeBatchTransferERC1155.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.royaltyInfo.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.getDefaultRoyaltyInfo.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.getRoyaltyInfoForToken.selector, permissionBits: 0});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.getTransferValidator.selector, permissionBits: 0});
        config.fallbackFunctions[4] =
            FallbackFunction({selector: this.getTransferValidationFunction.selector, permissionBits: 0});
        config.fallbackFunctions[5] = FallbackFunction({selector: this.hasRole.selector, permissionBits: 0});
        config.fallbackFunctions[6] =
            FallbackFunction({selector: this.setDefaultRoyaltyInfo.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[7] =
            FallbackFunction({selector: this.setRoyaltyInfoForToken.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[8] =
            FallbackFunction({selector: this.setTransferValidator.selector, permissionBits: Role._MANAGER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155

        config.supportedInterfaces = new bytes4[](3);
        config.supportedInterfaces[0] = 0x2a55205a; // IERC2981.
        config.supportedInterfaces[1] = 0xad0d7f6c; // ICreatorToken
        config.supportedInterfaces[2] = 0xa07d229a; // ICreatorTokenLegacy

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address royaltyRecipient, uint16 royaltyBps, address transferValidator)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(royaltyRecipient, royaltyBps, transferValidator);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC1155.transferFrom/safeTransferFrom
    function beforeTransferERC1155(address from, address to, uint256 _id, uint256 _value)
        external
        virtual
        override
        returns (bytes memory)
    {
        address transferValidator = getTransferValidator();
        if (transferValidator != address(0)) {
            ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, _id, _value);
        }
    }

    function beforeBatchTransferERC1155(address from, address to, uint256[] calldata ids, uint256[] calldata values)
        external
        virtual
        override
        returns (bytes memory)
    {
        address transferValidator = getTransferValidator();
        if (transferValidator != address(0)) {
            uint256 length = ids.length;
            for (uint256 i = 0; i < length; i++) {
                ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, ids[i], values[i]);
            }
        }
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        (address royaltyRecipient, uint16 royaltyBps, address transferValidator) =
            abi.decode(data, (address, uint16, address));
        _setDefaultRoyaltyInfo(royaltyRecipient, royaltyBps);
        _setTransferValidator(transferValidator);
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the royalty recipient and amount for a given sale.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        (address overrideRecipient, uint16 overrideBps) = getRoyaltyInfoForToken(_tokenId);
        (address defaultRecipient, uint16 defaultBps) = getDefaultRoyaltyInfo();

        receiver = overrideRecipient == address(0) ? defaultRecipient : overrideRecipient;

        uint16 bps = overrideBps == 0 ? defaultBps : overrideBps;
        royaltyAmount = (_salePrice * bps) / 10_000;
    }

    /// @notice Returns the overriden royalty info for a given token.
    function getRoyaltyInfoForToken(uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyStorage.Data storage data = RoyaltyStorage.data();
        RoyaltyInfo memory royaltyForToken = data.royaltyInfoForToken[_tokenId];

        return (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /// @notice Returns the default royalty info for a given token.
    function getDefaultRoyaltyInfo() public view returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = RoyaltyStorage.data().defaultRoyaltyInfo;
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /// @notice Sets the default royalty info for a given token.
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint16 _royaltyBps) external {
        _setDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
    }

    /// @notice Sets the royalty info for a specific NFT of a token collection.
    function setRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint16 _bps) external {
        if (_bps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().royaltyInfoForToken[_tokenId] = RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdated(_tokenId, _recipient, _bps);
    }

    /// @notice Returns the transfer validator contract address for this token contract.
    function getTransferValidator() public view returns (address validator) {
        validator = _royaltyStorage().transferValidator;
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)"));
        isViewFunction = true;
    }

    function setTransferValidator(address validator) external {
        _setTransferValidator(validator);
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        if (msg.sender != _royaltyStorage().transferValidator) {
            revert RoyaltyNotTransferValidator();
        }
        if (role == DEFAULT_ACCESS_CONTROL_ADMIN_ROLE) {
            return OwnableRoles(address(this)).hasAllRoles(account, Role._MANAGER_ROLE);
        }
        return OwnableRoles(address(this)).hasAllRoles(account, uint256(role));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setDefaultRoyaltyInfo(address _royaltyRecipient, uint16 _royaltyBps) internal {
        if (_royaltyBps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().defaultRoyaltyInfo = RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdated(_royaltyRecipient, _royaltyBps);
    }

    function _setTransferValidator(address validator) internal {
        bool isValidTransferValidator = validator.code.length > 0;

        if (validator != address(0) && !isValidTransferValidator) {
            revert RoyaltyInvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(address(getTransferValidator()), validator);

        _royaltyStorage().transferValidator = validator;
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
        return uint16(TOKEN_TYPE_ERC1155);
    }

    function _royaltyStorage() internal pure returns (RoyaltyStorage.Data storage) {
        return RoyaltyStorage.data();
    }

}
