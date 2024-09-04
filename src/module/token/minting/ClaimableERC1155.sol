// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BeforeMintCallbackERC1155} from "../../../callback/BeforeMintCallbackERC1155.sol";
import {BeforeMintWithSignatureCallbackERC1155} from "../../../callback/BeforeMintWithSignatureCallbackERC1155.sol";

library ClaimableStorage {

    /// @custom:storage-location erc7201:token.minting.claimable.erc1155
    bytes32 public constant CLAIMABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.claimable.erc1155")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // sale config: primary sale recipient, and platform fee recipient + BPS.
        ClaimableERC1155.SaleConfig saleConfig;
        // token ID => claim condition
        mapping(uint256 => ClaimableERC1155.ClaimCondition) claimConditionByTokenId;
        // UID => whether it has been used
        mapping(bytes32 => bool) uidUsed;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIMABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract ClaimableERC1155 is
    Module,
    BeforeMintCallbackERC1155,
    BeforeMintWithSignatureCallbackERC1155,
    IInstallationCallback
{

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Details for distributing the proceeds of a mint.
     *  @param primarySaleRecipient The address to which the total proceeds minus fees are sent.
     */
    struct SaleConfig {
        address primarySaleRecipient;
    }

    /**
     *  @notice Conditions under which tokens can be minted.
     *  @param availableSupply The total number of tokens that can be minted.
     *  @param allowlistMerkleRoot The allowlist of addresses who can mint tokens.
     *  @param pricePerUnit The price per token.
     *  @param currency The currency in which the price is denominated.
     *  @param startTimestamp The timestamp at which the minting window opens.
     *  @param endTimestamp The timestamp after which the minting window closes.
     *  @param auxData Use to store arbitrary data. i.e: merkle snapshot url
     */
    struct ClaimCondition {
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
        string auxData;
    }

    /**
     *  @notice The request struct signed by an authorized party to mint tokens.
     *
     *  @param startTimestamp The timestamp at which the minting request is valid.
     *  @param endTimestamp The timestamp at which the minting request expires.
     *  @param currency The address of the currency used to pay for the minted tokens.
     *  @param pricePerUnit The price per unit of the minted tokens.
     *  @param uid A unique identifier for the minting request.
     */
    struct ClaimSignatureParamsERC1155 {
        uint48 startTimestamp;
        uint48 endTimestamp;
        address currency;
        uint256 pricePerUnit;
        bytes32 uid;
    }

    /**
     *  @notice The parameters sent to the `beforeMintERC20` callback function.
     *
     *  @param request The minting request.
     *  @param signature The signature produced from signing the minting request.
     */
    struct ClaimParamsERC1155 {
        address currency;
        uint256 pricePerUnit;
        bytes32[] recipientAllowlistProof;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when incorrect amount of native token is sent.
    error ClaimableIncorrectNativeTokenSent();

    /// @dev Emitted when the minting request token is invalid.
    error ClaimableRequestInvalidToken();

    /// @dev Emitted when the minting request does not match the expected values.
    error ClaimableRequestMismatch();

    /// @dev Emitted when the minting request has expired.
    error ClaimableRequestOutOfTimeWindow();

    /// @dev Emitted when the minting request UID has been reused.
    error ClaimableRequestUidReused();

    /// @dev Emitted when the minting request signature is unauthorized.
    error ClaimableRequestUnauthorizedSignature();

    /// @dev Emitted when the mint is attempted outside the minting window.
    error ClaimableOutOfTimeWindow();

    /// @dev Emitted when the mint is out of supply.
    error ClaimableOutOfSupply();

    /// @dev Emitted when the mint is priced at an unexpected price or currency.
    error ClaimableIncorrectPriceOrCurrency();

    /// @dev Emitted when the minter is not in the allowlist.
    error ClaimableNotInAllowlist();

    /// @dev Emitted when the minting request signature is unauthorized.
    error ClaimableSignatureMintUnauthorized();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC1155.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeMintWithSignatureERC1155.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getSaleConfig.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setSaleConfig.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.getClaimConditionByTokenId.selector, permissionBits: 0});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setClaimConditionByTokenId.selector, permissionBits: Role._MINTER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMintERC1155(address _to, uint256 _id, uint256 _amount, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        ClaimParamsERC1155 memory _params = abi.decode(_data, (ClaimParamsERC1155));

        _validateClaimCondition(
            _to, _amount, _id, _params.currency, _params.pricePerUnit, _params.recipientAllowlistProof
        );

        _distributeMintPrice(msg.sender, _params.currency, _amount * _params.pricePerUnit);
    }

    function beforeMintWithSignatureERC1155(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data,
        address _signer
    ) external payable virtual override returns (bytes memory) {
        ClaimSignatureParamsERC1155 memory _params = abi.decode(_data, (ClaimSignatureParamsERC1155));

        if (!OwnableRoles(address(this)).hasAllRoles(_signer, Role._MINTER_ROLE)) {
            revert ClaimableSignatureMintUnauthorized();
        }

        _validateClaimSignatureParams(_amount, _id, _params);

        _distributeMintPrice(msg.sender, _params.currency, _amount * _params.pricePerUnit);
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address primarySaleRecipient = abi.decode(data, (address));
        _claimableStorage().saleConfig = SaleConfig(primarySaleRecipient);
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address primarySaleRecipient) external pure returns (bytes memory) {
        return abi.encode(primarySaleRecipient);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                        Encode mint params
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded mint params, to be used in `beforeMint` fallback function
    function encodeBytesBeforeMintERC1155(ClaimParamsERC1155 memory params) external pure returns (bytes memory) {
        return abi.encode(params);
    }

    /// @dev Returns bytes encoded mintWithSignature params, to be used in `beforeMintWithSignature` fallback function
    function encodeBytesBeforeMintWithSignatureERC1155(ClaimSignatureParamsERC1155 memory params)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig() external view returns (address primarySaleRecipient) {
        SaleConfig memory saleConfig = _claimableStorage().saleConfig;
        return (saleConfig.primarySaleRecipient);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        _claimableStorage().saleConfig = SaleConfig(_primarySaleRecipient);
    }

    /// @notice Returns the claim condition for a token and a specific token ID.
    function getClaimConditionByTokenId(uint256 _id) external view returns (ClaimCondition memory claimCondition) {
        return _claimableStorage().claimConditionByTokenId[_id];
    }

    /// @notice Sets the claim condition for a token and a specific token ID.
    function setClaimConditionByTokenId(uint256 _id, ClaimCondition memory _claimCondition) external {
        _claimableStorage().claimConditionByTokenId[_id] = _claimCondition;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies a claim against the active claim condition.
    function _validateClaimCondition(
        address _recipient,
        uint256 _amount,
        uint256 _tokenId,
        address _currency,
        uint256 _pricePerUnit,
        bytes32[] memory _allowlistProof
    ) internal {
        ClaimCondition memory condition = _claimableStorage().claimConditionByTokenId[_tokenId];

        if (block.timestamp < condition.startTimestamp || condition.endTimestamp <= block.timestamp) {
            revert ClaimableOutOfTimeWindow();
        }

        if (_currency != condition.currency || _pricePerUnit != condition.pricePerUnit) {
            revert ClaimableIncorrectPriceOrCurrency();
        }

        if (_amount > condition.availableSupply) {
            revert ClaimableOutOfSupply();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimableNotInAllowlist();
            }
        }

        _claimableStorage().claimConditionByTokenId[_tokenId].availableSupply -= _amount;
    }

    /// @dev Verifies the claim request and signature.
    function _validateClaimSignatureParams(uint256 _amount, uint256 _tokenId, ClaimSignatureParamsERC1155 memory _req)
        internal
    {
        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert ClaimableRequestOutOfTimeWindow();
        }

        if (_claimableStorage().uidUsed[_req.uid]) {
            revert ClaimableRequestUidReused();
        }

        if (_amount > _claimableStorage().claimConditionByTokenId[_tokenId].availableSupply) {
            revert ClaimableOutOfSupply();
        }

        _claimableStorage().uidUsed[_req.uid] = true;
        _claimableStorage().claimConditionByTokenId[_tokenId].availableSupply -= _amount;
    }

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert ClaimableIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimableStorage().saleConfig;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert ClaimableIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price);
        } else {
            if (msg.value > 0) {
                revert ClaimableIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price);
        }
    }

    function _claimableStorage() internal pure returns (ClaimableStorage.Data storage) {
        return ClaimableStorage.data();
    }

}
