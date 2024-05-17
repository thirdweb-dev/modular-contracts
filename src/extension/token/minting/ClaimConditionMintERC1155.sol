// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library ClaimConditionMintStorage {
    /// @custom:storage-location erc7201:claim.condition.mint.storage
    bytes32 public constant CLAIM_CONDITION_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("claim.condition.mint.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token address => sale config: primary sale recipient, and platform fee recipient + BPS.
        mapping(address => ClaimConditionMint1155.SaleConfig) saleConfig;
        // token => token ID => claim condition
        mapping(address => mapping(uint256 => ClaimConditionMint1155.ClaimCondition)) claimConditionByTokenId;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIM_CONDITION_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimConditionMint1155 is ModularExtension {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Conditions under which tokens can be minted.
     *  @param availableSupply The total number of tokens that can be minted.
     *  @param allowlistMerkleRoot The allowlist of addresses who can mint tokens.
     *  @param pricePerUnit The price per token.
     *  @param currency The currency in which the price is denominated.
     *  @param startTimestamp The timestamp at which the minting window opens.
     *  @param endTimestamp The timestamp after which the minting window closes.
     */
    struct ClaimCondition {
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
    }

    /**
     *  @notice The parameters required to mint tokens.
     *  @param allowlistProof The proof of inclusion in the allowlist.
     *  @param expectedPricePerUnit The expected price per token.
     *  @param expectedCurrency The expected currency in which the price is denominated.
     */
    struct ClaimParams {
        bytes32[] allowlistProof;
        uint256 expectedPricePerUnit;
        address expectedCurrency;
    }

    /**
     *  @notice Details for distributing the proceeds of a mint.
     *  @param primarySaleRecipient The address to which the total proceeds minus fees are sent.
     *  @param platformFeeRecipient The address to which the platform fee is sent.
     *  @param platformFeeBps The platform fee in basis points. 10_000 BPS = 100%.
     */
    struct SaleConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when incorrect amount of native token is sent.
    error ClaimConditionMintIncorrectNativeTokenSent();

    /// @dev Emitted when the mint price or currency does not match the expected price or currency.
    error ClaimConditionMintPriceMismatch();

    /// @dev Emitted when the mint is attempted outside the minting window.
    error ClaimConditionMintOutOfTimeWindow();

    /// @dev Emitted when the mint is out of supply.
    error ClaimConditionMintOutOfSupply();

    /// @dev Emitted when the minter is not in the allowlist.
    error ClaimConditionMintNotInAllowlist();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[2] = CallbackFunction(this.beforeMintERC1155.selector, CallType.CALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getClaimConditionByTokenId.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setClaimConditionByTokenId.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });

        config.requiredInterfaceId = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC1155Core.mint function.
    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC1155(_to, _id, _quantity, _params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _claimConditionMintStorage().saleConfig[token] =
            SaleConfig(_primarySaleRecipient, _platformFeeRecipient, _platformFeeBps);
    }

    /// @notice Returns the claim condition for a token and a specific token ID.
    function getClaimConditionByTokenId(address _token, uint256 _id)
        external
        view
        returns (ClaimCondition memory claimCondition)
    {
        return _claimConditionMintStorage().claimConditionByTokenId[_token][_id];
    }

    /// @notice Sets the claim condition for a token and a specific token ID.
    function setClaimConditionByTokenId(uint256 _id, ClaimCondition memory _claimCondition) external {
        address token = msg.sender;
        _claimConditionMintStorage().claimConditionByTokenId[token][_id] = _claimCondition;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Processes a mint for an ERC1155 token against the claim condition set for it.
    function _allowlistedMintERC1155(address _recipient, uint256 _id, uint256 _quantity, ClaimParams memory _params)
        internal
    {
        address token = msg.sender;

        ClaimCondition memory claimCondition = _claimConditionMintStorage().claimConditionByTokenId[token][_id];

        if (
            claimCondition.currency != _params.expectedCurrency
                || claimCondition.pricePerUnit != _params.expectedPricePerUnit
        ) {
            revert ClaimConditionMintPriceMismatch();
        }

        if (block.timestamp < claimCondition.startTimestamp || claimCondition.endTimestamp <= block.timestamp) {
            revert ClaimConditionMintOutOfTimeWindow();
        }

        if (_quantity > claimCondition.availableSupply) {
            revert ClaimConditionMintOutOfSupply();
        }

        if (claimCondition.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimCondition.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimConditionMintNotInAllowlist();
            }
        }

        _claimConditionMintStorage().claimConditionByTokenId[token][_id].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, _quantity * _params.expectedPricePerUnit);
    }

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert ClaimConditionMintIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert ClaimConditionMintIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    function _claimConditionMintStorage() internal pure returns (ClaimConditionMintStorage.Data storage) {
        return ClaimConditionMintStorage.data();
    }
}
