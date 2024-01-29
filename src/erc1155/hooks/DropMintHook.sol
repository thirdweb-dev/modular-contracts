// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {IClaimCondition} from "../../interface/extension/IClaimCondition.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {ERC1155Hook} from "./ERC1155Hook.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

contract DropMintHook is IClaimCondition, IFeeConfig, ERC1155Hook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @param proof Proof of concerned wallet's inclusion in an allowlist.
     *  @param quantityLimitPerWallet The total quantity of tokens the allowlisted wallet is eligible to claim over time.
     *  @param pricePerToken The price per token the allowlisted wallet must pay to claim tokens.
     *  @param currency The currency in which the allowlisted wallet must pay the price for claiming tokens.
     */
    struct AllowlistProof {
        bytes32[] proof;
        uint256 quantityLimitPerWallet;
        uint256 pricePerToken;
        address currency;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, uint256 id, ClaimCondition condition, bool resetEligibility);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error DropMintHookNotAuthorized();

    /// @notice Emitted when the condition price or currency is unexpected.
    error DropMintHookUnexpectedPriceOrCurrency();

    /// @notice Emitted when claiming an invalid quantity of tokens.
    error DropMintHookInvalidQuantity();

    /// @notice Emitted when the max supply of tokens has been claimed.
    error DropMintHookMaxSupplyClaimed();

    /// @notice Emitted when the claim condition has not started yet.
    error DropMintHookMintNotStarted();

    /// @notice Emitted when incorrect native token value is sent.
    error DropMintHookIncorrectValueSent();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => token-id => the claim conditions for minting the token.
    mapping(address => mapping(uint256 => ClaimCondition)) private _claimCondition;

    /// @notice Mapping from condition ID => hash(claimer, token, token-id) => supply claimed by wallet.
    mapping(bytes32 => mapping(bytes32 => uint256)) private _supplyClaimedByWallet;

    /// @notice Mapping from token => token-id => condition ID.
    mapping(address => mapping(uint256 => bytes32)) private _conditionId;

    /// @notice Mapping from token => token-id => fee config for the token.
    mapping(address => mapping(uint256 => FeeConfig)) private _feeConfig;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert DropMintHookNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "address,uint256,bytes32[],uint256,uint256,address";
    }

    /**
     *  @notice Checks a request to claim NFTs against the active claim condition's criteria.
     *  @param _token The token to claim.
     *  @param _claimer The address that is claiming tokens.
     *  @param _quantity The quantity of tokens to claim.
     *  @param _currency The currency in which the claimer must pay the price for claiming tokens.
     *  @param _pricePerToken The price per token claimed the claimer must pay.
     *  @param _allowlistProof The proof of the claimer's inclusion in an allowlist.
     */
    function verifyClaim(
        address _token,
        uint256 _id,
        address _claimer,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        AllowlistProof memory _allowlistProof
    ) public view virtual returns (bool isOverride) {
        ClaimCondition memory currentClaimPhase = _claimCondition[_token][_id];

        uint256 claimLimit = currentClaimPhase.quantityLimitPerWallet;
        uint256 claimPrice = currentClaimPhase.pricePerToken;
        address claimCurrency = currentClaimPhase.currency;

        /*
     * Here `isOverride` implies that if the merkle proof verification fails,
     * the claimer would claim through open claim limit instead of allowlisted limit.
     */
        if (currentClaimPhase.merkleRoot != bytes32(0)) {
            isOverride = MerkleProofLib.verify(
                _allowlistProof.proof,
                currentClaimPhase.merkleRoot,
                keccak256(
                    abi.encodePacked(
                        _claimer,
                        _allowlistProof.quantityLimitPerWallet,
                        _allowlistProof.pricePerToken,
                        _allowlistProof.currency
                    )
                )
            );
        }

        if (isOverride) {
            claimLimit =
                _allowlistProof.quantityLimitPerWallet != 0 ? _allowlistProof.quantityLimitPerWallet : claimLimit;
            claimPrice = _allowlistProof.pricePerToken != type(uint256).max ? _allowlistProof.pricePerToken : claimPrice;
            claimCurrency = _allowlistProof.pricePerToken != type(uint256).max && _allowlistProof.currency != address(0)
                ? _allowlistProof.currency
                : claimCurrency;
        }

        uint256 supplyClaimedByWallet = getSupplyClaimedByWallet(_token, _id, _claimer);

        if (_currency != claimCurrency || _pricePerToken != claimPrice) {
            revert DropMintHookUnexpectedPriceOrCurrency();
        }

        if (_quantity == 0 || (_quantity + supplyClaimedByWallet > claimLimit)) {
            revert DropMintHookInvalidQuantity();
        }

        if (currentClaimPhase.supplyClaimed + _quantity > currentClaimPhase.maxClaimableSupply) {
            revert DropMintHookMaxSupplyClaimed();
        }

        if (currentClaimPhase.startTimestamp > block.timestamp) {
            revert DropMintHookMintNotStarted();
        }
    }

    /**
     *  @notice Returns the claim condition for a given token.
     *  @param _token The token to get the claim condition for.
     *  @param _claimer The address to get the supply claimed for
     */
    function getSupplyClaimedByWallet(address _token, uint256 _id, address _claimer) public view returns (uint256) {
        return _supplyClaimedByWallet[_conditionId[_token][_id]][keccak256(abi.encode(_claimer, _token, _id))];
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfigForToken(address _token, uint256 _id) external view returns (FeeConfig memory) {
        return _feeConfig[_token][_id];
    }

    /// @notice Returns the fee config for a token.
    function getDefaultFeeConfig(address _token) external view returns (FeeConfig memory) {
        return _feeConfig[_token][type(uint256).max];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(address _claimer, uint256 _id, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;

        (address currency, uint256 pricePerToken, AllowlistProof memory allowlistProof) =
            abi.decode(_encodedArgs, (address, uint256, AllowlistProof));

        verifyClaim(token, _id, _claimer, _quantity, currency, pricePerToken, allowlistProof);

        // Update contract state.
        tokenIdToMint = _id;
        quantityToMint = _quantity;

        _claimCondition[token][_id].supplyClaimed += _quantity;
        _supplyClaimedByWallet[_conditionId[token][_id]][keccak256(abi.encode(_claimer, token, _id))] += _quantity;

        _collectPrice(_claimer, _id, _quantity * pricePerToken, currency);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the claim condition for.
     *  @param _condition The claim condition to set.
     *  @param _resetClaimEligibility Whether to reset the claim eligibility of all wallets.
     */
    function setClaimCondition(
        address _token,
        uint256 _id,
        ClaimCondition calldata _condition,
        bool _resetClaimEligibility
    ) external onlyAdmin(_token) {
        bytes32 targetConditionId = _conditionId[_token][_id];
        uint256 supplyClaimedAlready = _claimCondition[_token][_id].supplyClaimed;

        if (_resetClaimEligibility) {
            supplyClaimedAlready = 0;
            targetConditionId = keccak256(abi.encodePacked(msg.sender, block.number, _id));
        }

        if (supplyClaimedAlready > _condition.maxClaimableSupply) {
            revert DropMintHookMaxSupplyClaimed();
        }

        _claimCondition[_token][_id] = ClaimCondition({
            startTimestamp: _condition.startTimestamp,
            maxClaimableSupply: _condition.maxClaimableSupply,
            supplyClaimed: supplyClaimedAlready,
            quantityLimitPerWallet: _condition.quantityLimitPerWallet,
            merkleRoot: _condition.merkleRoot,
            pricePerToken: _condition.pricePerToken,
            currency: _condition.currency,
            metadata: _condition.metadata
        });
        _conditionId[_token][_id] = targetConditionId;

        emit ClaimConditionUpdate(_token, _id, _condition, _resetClaimEligibility);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfigForToken(address _token, uint256 _id, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token][_id] = _config;
        emit FeeConfigUpdateERC1155(_token, _id, _config);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setDefaultFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token][type(uint256).max] = _config;
        emit FeeConfigUpdateERC1155(_token, type(uint256).max, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _collectPrice(address _minter, uint256 _id, uint256 _totalPrice, address _currency) internal {
        if (_totalPrice == 0) {
            if (msg.value > 0) {
                revert DropMintHookIncorrectValueSent();
            }
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = _feeConfig[token][_id];

        if (feeConfig.primarySaleRecipient == address(0) || feeConfig.platformFeeRecipient == address(0)) {
            feeConfig = _feeConfig[token][type(uint256).max];
        }

        bool payoutPlatformFees = feeConfig.platformFeeBps > 0 && feeConfig.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if (payoutPlatformFees) {
            platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            if (msg.value != _totalPrice) {
                revert DropMintHookIncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        } else {
            if (msg.value > 0) {
                revert DropMintHookIncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        }
    }
}
