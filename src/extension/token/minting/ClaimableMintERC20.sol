// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library ClaimableMintStorage {
    /// @custom:storage-location erc7201:claim.condition.mint.storage
    bytes32 public constant CLAIMABLE_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.claimable")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // sale config: primary sale recipient, and platform fee recipient + BPS.
        ClaimableMintERC20.SaleConfig saleConfig;
        // claim condition
        ClaimableMintERC20.ClaimCondition claimCondition;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIMABLE_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimableMintERC20 is ModularExtension {
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
     */
    struct SaleConfig {
        address primarySaleRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when incorrect amount of native token is sent.
    error ClaimableMintIncorrectNativeTokenSent();

    /// @dev Emitted when the mint price or currency does not match the expected price or currency.
    error ClaimableMintPriceMismatch();

    /// @dev Emitted when the mint is attempted outside the minting window.
    error ClaimableMintOutOfTimeWindow();

    /// @dev Emitted when the mint is out of supply.
    error ClaimableMintOutOfSupply();

    /// @dev Emitted when the minter is not in the allowlist.
    error ClaimableMintNotInAllowlist();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC20.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getSaleConfig.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setSaleConfig.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.getClaimCondition.selector, permissionBits: 0});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setClaimCondition.selector, permissionBits: Role._MINTER_ROLE});
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC20Core.mint function.
    function beforeMintERC20(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC20(_to, _quantity, _params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig() external view returns (address primarySaleRecipient) {
        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig;
        return (saleConfig.primarySaleRecipient);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        _claimConditionMintStorage().saleConfig = SaleConfig(_primarySaleRecipient);
    }

    /// @notice Returns the claim condition for a token.
    function getClaimCondition() external view returns (ClaimCondition memory claimCondition) {
        return _claimConditionMintStorage().claimCondition;
    }

    /// @notice Sets the claim condition for a token.
    function setClaimCondition(ClaimCondition memory _claimCondition) external {
        _claimConditionMintStorage().claimCondition = _claimCondition;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Processes a mint for an ERC20 token against the claim condition set for it.
    function _allowlistedMintERC20(address _recipient, uint256 _quantity, ClaimParams memory _params) internal {
        ClaimCondition memory claimCondition = _claimConditionMintStorage().claimCondition;

        if (
            claimCondition.currency != _params.expectedCurrency
                || claimCondition.pricePerUnit != _params.expectedPricePerUnit
        ) {
            revert ClaimableMintPriceMismatch();
        }

        if (block.timestamp < claimCondition.startTimestamp || claimCondition.endTimestamp <= block.timestamp) {
            revert ClaimableMintOutOfTimeWindow();
        }

        if (_quantity > claimCondition.availableSupply) {
            revert ClaimableMintOutOfSupply();
        }

        if (claimCondition.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimCondition.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimableMintNotInAllowlist();
            }
        }

        _claimConditionMintStorage().claimCondition.availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, (_quantity * _params.expectedPricePerUnit) / 1e18);
    }

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert ClaimableMintIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert ClaimableMintIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price);
        }
    }

    function _claimConditionMintStorage() internal pure returns (ClaimableMintStorage.Data storage) {
        return ClaimableMintStorage.data();
    }
}
