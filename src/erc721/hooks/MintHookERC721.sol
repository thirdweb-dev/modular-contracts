// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {IClaimCondition} from "../../interface/extension/IClaimConditionTwo.sol";
import {IMintRequest} from "../../interface/extension/IMintRequest.sol";
import {IMintRequestERC721} from "../../interface/extension/IMintRequestERC721.sol";

import {ERC721Hook} from "./ERC721Hook.sol";
import {EIP712} from "../../extension/EIP712.sol";

import {ECDSA} from "../../lib/ECDSA.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

contract MintHookERC721 is IFeeConfig, IMintRequest, IClaimCondition, EIP712, ERC721Hook {

    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The EIP-712 typehash for the mint request struct.
    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );

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

    /// @notice Emitted when caller is not token.
    error MintHookNotToken();

    /// @notice Emitted when caller is not token core admin.
    error MintHookNotAuthorized();

    /// @notice Emitted when minting invalid quantity.
    error MintHookInvalidQuantity(uint256 quantityToMint);

    /// @notice Emitted when minting with incorrect price.
    error MintHookInvalidPrice(uint256 expectedPrice, uint256 actualPrice);

    /// @notice Emittted when minting with invalid currency.
    error MintHookInvalidCurrency(address expectedCurrency, address actualCurrency);

    /// @notice Emitted when maximum available supply has been minted.
    error MintHookMaxSupplyClaimed();

    /// @notice Emitted when minter not in allowlist.
    error MintHookNotInAllowlist();

    /// @notice Emitted when the claim condition has not started yet.
    error MintHookMintNotStarted();

    /// @notice Emitted when minting to an invalid recipient.
    error MintHookInvalidRecipient();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the next token ID to mint.
    mapping(address => uint256) private _nextTokenIdToMint;

    /// @notice Mapping from token => fee config for the token.
    mapping(address => FeeConfig) private _feeConfig;

    /*//////////////////////////////////////////////////////////////
                               DROP STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the claim conditions for minting the token.
    mapping(address => ClaimCondition) private _claimCondition;

    /// @notice Mapping from hash(claimer, conditionID) => supply claimed by wallet.
    mapping(bytes32 =>  uint256) private _supplyClaimedByWallet;

    /// @notice Mapping from token => condition ID.
    mapping(address => bytes32) private _conditionId;

    /// @dev Mapping from permissioned mint request UID => whether the mint request is processed.
    mapping(bytes32 => bool) private _uidUsed;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert MintHookNotAuthorized();
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
        argSignature = "address,uint256,address,uint256,uint256,address,bytes32[],bytes,uint128,uint128,bytes32";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return _nextTokenIdToMint[_token];
    }

    /**
     *  @notice Verifies that a given claim is valid.
     *
     *  @param _token The token to mint.
     *  @param _claimer The address to mint tokens for.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _pricePerToken The price per token.
     *  @param _currency The currency to pay with.
     *  @param _allowlistProof The proof of the claimer's inclusion in an allowlist, if any.
     *  @return isAllowlisted Whether the claimer is allowlisted.
     */
    function verifyClaim(
        address _token,
        address _claimer,
        uint256 _quantity,
        uint256 _pricePerToken,
        address _currency,
        bytes32[] memory _allowlistProof
    ) public view virtual returns (bool isAllowlisted) {
        ClaimCondition memory currentClaimPhase = _claimCondition[_token];
        
        if (currentClaimPhase.startTimestamp > block.timestamp) {
            revert MintHookMintNotStarted();
        }

        /*
         * Here `isOverride` implies that if the merkle proof verification fails,
         * the claimer would claim through open claim limit instead of allowlisted limit.
         */
        if (currentClaimPhase.merkleRoot != bytes32(0)) {
            isAllowlisted = MerkleProofLib.verify(
                _allowlistProof,
                currentClaimPhase.merkleRoot,
                keccak256(
                    abi.encodePacked(
                        _claimer
                    )
                )
            );

            if(!isAllowlisted) {
                revert MintHookNotInAllowlist();
            }
        }

        if (_currency != currentClaimPhase.currency) {
            revert MintHookInvalidCurrency(currentClaimPhase.currency, _currency);
        }

        if (_pricePerToken != currentClaimPhase.pricePerToken) {
            revert MintHookInvalidPrice(currentClaimPhase.pricePerToken, _pricePerToken);
        }

        if (_quantity == 0 || (_quantity + getSupplyClaimedByWallet(_token, _claimer) > currentClaimPhase.quantityLimitPerWallet)) {
            revert MintHookInvalidQuantity(_quantity);
        }

        if (currentClaimPhase.supplyClaimed + _quantity > currentClaimPhase.maxClaimableSupply) {
            revert MintHookMaxSupplyClaimed();
        }
    }

    /**
     *  @notice Returns whether a mint request is permissioned.
     *
     *  @param _req The mint request to check.
     *  @return isPermissioned Whether the mint request is permissioned.
     */
    function isPermissionedClaim(MintRequest memory _req)
        public
        view
        returns (bool isPermissioned)
    {

        if(
            _req.permissionSignature.length == 0
                || _req.sigValidityStartTimestamp > block.timestamp
                || block.timestamp > _req.sigValidityEndTimestamp
                || _uidUsed[_req.sigUid]
        ) {
            return false;
        }

        address signer = _recoverAddress(_req);
        isPermissioned = !IPermission(_req.token).hasRole(signer, ADMIN_ROLE_BITS);
    }

    /**
     *  @notice Returns the claim condition for a given token.
     *  @param _token The token to get the claim condition for.
     *  @param _claimer The address to get the supply claimed for
     */
    function getSupplyClaimedByWallet(address _token, address _claimer) public view returns (uint256) {
        return _supplyClaimedByWallet[keccak256(abi.encode(_conditionId[_token], _claimer))];
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfig(address _token) external view returns (FeeConfig memory) {
        return _feeConfig[_token];
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
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        (MintRequest memory req) = abi.decode(_encodedArgs, (MintRequest));
        
        if(req.token != msg.sender) {
            revert MintHookNotToken();
        }
        if(req.quantity != _quantity) {
            revert MintHookInvalidQuantity(_quantity);
        }

        if(req.minter != _claimer) {
            revert MintHookInvalidRecipient();
        } 

        // Check against active claim condition unless permissioned.
        if(!isPermissionedClaim(req)) {
            verifyClaim(req.token, req.minter, req.quantity, req.pricePerToken, req.currency, req.allowlistProof);
            _claimCondition[req.token].supplyClaimed += req.quantity;
            _supplyClaimedByWallet[keccak256(abi.encode(_conditionId[req.token], req.minter))] += req.quantity;
        } else {
            _uidUsed[req.sigUid] = true;
        }

        tokenIdToMint = _nextTokenIdToMint[req.token]++;
        quantityToMint = req.quantity;

        _collectPrice(req.minter, req.pricePerToken * req.quantity, req.currency);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }

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
            targetConditionId = keccak256(abi.encodePacked(_token, targetConditionId));
        }

        if (supplyClaimedAlready > _condition.maxClaimableSupply) {
            revert MintHookMaxSupplyClaimed();
        }

        _claimCondition[_token] = ClaimCondition({
            startTimestamp: _condition.startTimestamp,
            endTimestamp: _condition.endTimestamp,
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distributes the sale value of minting a token.
    function _collectPrice(address _minter, uint256 _totalPrice, address _currency) internal {
        if (_totalPrice == 0) {
            if (msg.value > 0) {
                revert MintHookInvalidPrice(0, msg.value);
            }
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = _feeConfig[token];

        bool payoutPlatformFees = feeConfig.platformFeeBps > 0 && feeConfig.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if (payoutPlatformFees) {
            platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            if (msg.value != _totalPrice) {
                revert MintHookInvalidPrice(_totalPrice, msg.value);
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        } else {
            if (msg.value > 0) {
                revert MintHookInvalidPrice(0, msg.value);
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        }
    }

    /// @dev Returns the domain name and version for the EIP-712 domain separator
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "MintHookERC721";
        version = "1";
    }

    /// @dev Returns the address of the signer of the mint request.
    function _recoverAddress(MintRequest memory _req) internal view returns (address) {
        return _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _req.token,
                    _req.tokenId,
                    _req.minter,
                    _req.quantity,
                    _req.pricePerToken,
                    _req.currency,
                    _req.allowlistProof,
                    keccak256(_req.permissionSignature),
                    _req.sigValidityStartTimestamp,
                    _req.sigValidityEndTimestamp,
                    _req.sigUid
                )
            )
        ).recover(_req.permissionSignature);
    }
}