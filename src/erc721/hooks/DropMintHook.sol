// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IClaimCondition} from "../../interface/extension/IClaimCondition.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {TokenHook} from "../../extension/TokenHook.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";

contract DropMintHook is IClaimCondition, TokenHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

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
    event ClaimConditionUpdate(address indexed token, ClaimCondition condition, bool resetEligibility);

    /// @notice Emitted when the next token ID to mint is updated.
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

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

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the next token ID to mint.
    mapping(address => uint256) private _nextTokenIdToMint;

    /// @notice Mapping from token => the claim conditions for minting the token.
    mapping(address => ClaimCondition) private _claimCondition;

    /// @notice Mapping from condition ID => hash(claimer, token) => supply claimed by wallet.
    mapping(bytes32 => mapping(bytes32 => uint256)) private _supplyClaimedByWallet;

    /// @notice Mapping from token => condition ID.
    mapping(address => bytes32) private _conditionId;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if(!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert DropMintHookNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "address,uint256,bytes32[],uint256,uint256,address";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return _nextTokenIdToMint[_token];
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
        address _claimer,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        AllowlistProof memory _allowlistProof
    ) public view virtual returns (bool isOverride) {
        ClaimCondition memory currentClaimPhase = _claimCondition[_token];

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

        uint256 supplyClaimedByWallet = getSupplyClaimedByWallet(_token, _claimer);

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
    function getSupplyClaimedByWallet(address _token, address _claimer) public view returns (uint256) {
        return _supplyClaimedByWallet[_conditionId[_token]][keccak256(abi.encode(_claimer, _token))];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return mintParams The details around which to execute a mint.
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        override
        returns (MintParams memory mintParams)
    {
        address token = msg.sender;

        (address currency, uint256 pricePerToken, AllowlistProof memory allowlistProof) =
            abi.decode(_encodedArgs, (address, uint256, AllowlistProof));

        verifyClaim(token, _claimer, _quantity, currency, pricePerToken, allowlistProof);

        // Update contract state.
        mintParams.tokenIdToMint = _nextTokenIdToMint[token]++;
        mintParams.quantityToMint = uint96(_quantity);
        mintParams.currency = currency;
        mintParams.totalPrice = _quantity * pricePerToken;

        _claimCondition[token].supplyClaimed += _quantity;
        _supplyClaimedByWallet[_conditionId[token]][keccak256(abi.encode(_claimer, token))] += _quantity;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the next token ID to mint for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the next token ID to mint for.
     *  @param _nextIdToMint The next token ID to mint.
     */
    function setNextIdToMint(address _token, uint256 _nextIdToMint) external onlyAdmin(_token) {
        _nextTokenIdToMint[_token] = _nextIdToMint;
        emit NextTokenIdUpdate(_token, _nextIdToMint);
    }

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the claim condition for.
     *  @param _condition The claim condition to set.
     *  @param _resetClaimEligibility Whether to reset the claim eligibility of all wallets.
     */
    function setClaimCondition(address _token, ClaimCondition calldata _condition, bool _resetClaimEligibility)
        external
        onlyAdmin(_token)
    {
        bytes32 targetConditionId = _conditionId[_token];
        uint256 supplyClaimedAlready = _claimCondition[_token].supplyClaimed;

        if (_resetClaimEligibility) {
            supplyClaimedAlready = 0;
            targetConditionId = keccak256(abi.encodePacked(msg.sender, block.number));
        }

        if (supplyClaimedAlready > _condition.maxClaimableSupply) {
            revert DropMintHookMaxSupplyClaimed();
        }

        _claimCondition[_token] = ClaimCondition({
            startTimestamp: _condition.startTimestamp,
            maxClaimableSupply: _condition.maxClaimableSupply,
            supplyClaimed: supplyClaimedAlready,
            quantityLimitPerWallet: _condition.quantityLimitPerWallet,
            merkleRoot: _condition.merkleRoot,
            pricePerToken: _condition.pricePerToken,
            currency: _condition.currency,
            metadata: _condition.metadata
        });
        _conditionId[_token] = targetConditionId;

        emit ClaimConditionUpdate(_token, _condition, _resetClaimEligibility);
    }
}
