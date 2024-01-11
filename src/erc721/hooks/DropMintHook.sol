// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../../interface/extension/IClaimCondition.sol";
import "../../interface/extension/IPermission.sol";

import "../../lib/MerkleProofLib.sol"; 
import "../../lib/SafeTransferLib.sol"; 

import "../../extension/TokenHook.sol";

contract DropMintHook is IClaimCondition, TokenHook {

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AllowlistProof {
        bytes32[] proof;
        uint256 quantityLimitPerWallet;
        uint256 pricePerToken;
        address currency;
    }

    struct FeeConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimConditionUpdate(address indexed token, ClaimCondition condition, bool resetEligibility);
    event FeeConfigUpdate(address indexed token, FeeConfig feeConfig);
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _nextTokenIdToMint;
    mapping(address => FeeConfig) private _feeConfig;
    mapping(address => ClaimCondition) private _claimCondition;
    mapping(bytes32 => mapping(bytes32 => uint256)) private _supplyClaimedByWallet;
    mapping(address => bytes32) private _conditionId;


    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "address,uint256,bytes32[],uint256,uint256,address";
    }

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
            claimLimit = _allowlistProof.quantityLimitPerWallet != 0
                ? _allowlistProof.quantityLimitPerWallet
                : claimLimit;
            claimPrice = _allowlistProof.pricePerToken != type(uint256).max
                ? _allowlistProof.pricePerToken
                : claimPrice;
            claimCurrency = _allowlistProof.pricePerToken != type(uint256).max && _allowlistProof.currency != address(0)
                ? _allowlistProof.currency
                : claimCurrency;
        }

        uint256 supplyClaimedByWallet = getSupplyClaimedByWallet(_token, _claimer);

        if (_currency != claimCurrency || _pricePerToken != claimPrice) {
            revert("!PriceOrCurrency");
        }

        if (_quantity == 0 || (_quantity + supplyClaimedByWallet > claimLimit)) {
            revert("!Qty");
        }

        if (currentClaimPhase.supplyClaimed + _quantity > currentClaimPhase.maxClaimableSupply) {
            revert("!MaxSupply");
        }

        if (currentClaimPhase.startTimestamp > block.timestamp) {
            revert("cant claim yet");
        }
    }

    function getSupplyClaimedByWallet(address _token, address _claimer) public view returns (uint256) {
        return _supplyClaimedByWallet[_conditionId[_token]][keccak256(abi.encode(_claimer, _token))];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address _claimer, uint256 _quantity, bytes memory _data)
        external
        payable
        override
        returns (uint256 tokenIdToMint)
    {
        address token = msg.sender;

        (
            address currency,
            uint256 pricePerToken,
            AllowlistProof memory allowlistProof
        ) = abi.decode(_data, (address, uint256, AllowlistProof));

        verifyClaim(token, _claimer, _quantity, currency, pricePerToken, allowlistProof);

        // Update contract state.
        tokenIdToMint = _nextTokenIdToMint[token]++;
        _claimCondition[token].supplyClaimed += _quantity;
        _supplyClaimedByWallet[_conditionId[token]][keccak256(abi.encode(_claimer, token))] += _quantity;

        // If there's a price, collect price.
        _collectPriceOnClaim(token, _claimer, _quantity, currency, pricePerToken);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setNextIdToMint(address _token, uint256 _nextIdToMint) external onlyAdmin(_token) {
        _nextTokenIdToMint[_token] = _nextIdToMint;
        emit NextTokenIdUpdate(_token, _nextIdToMint);
    }

    function setFeeConfig(address _token, FeeConfig calldata _config) external onlyAdmin(_config.primarySaleRecipient) {
        _feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }

    function setClaimConditions(address _token, ClaimCondition calldata _condition, bool _resetClaimEligibility) external onlyAdmin(_token) {
        bytes32 targetConditionId = _conditionId[_token];
        uint256 supplyClaimedAlready = _claimCondition[_token].supplyClaimed;

        if (_resetClaimEligibility) {
            supplyClaimedAlready = 0;
            targetConditionId = keccak256(abi.encodePacked(msg.sender, block.number));
        }

        if (supplyClaimedAlready > _condition.maxClaimableSupply) {
            revert("max supply claimed");
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

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _collectPriceOnClaim(
        address _token,
        address _claimer,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal {
        if (_pricePerToken == 0) {
            require(msg.value == 0, "!Value");
            return;
        }

        FeeConfig memory feeConfig = _feeConfig[_token];

        uint256 totalPrice = _quantityToClaim * _pricePerToken;
        uint256 platformFees = (totalPrice * feeConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN) {
            require(msg.value == totalPrice, "!Price");
            SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, totalPrice);
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, totalPrice - platformFees);
        } else {
            require(msg.value == 0, "!Value");
            SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.platformFeeRecipient, platformFees);
            SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.primarySaleRecipient, totalPrice - platformFees);
        }
    }
}