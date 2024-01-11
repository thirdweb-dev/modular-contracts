// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.
///
/// Note that this contract is designed to hold "shared state" i.e. it is deployed once by anyone, and can be
/// used by anyone for their copy of `ERC721Core`.

import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";

import {TokenHook} from "../../extension/TokenHook.sol";
import {Permission} from "../../extension/Permission.sol";

import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {LibString} from "../../lib/LibString.sol";

contract AllowlistMintHook is TokenHook, IFeeConfig {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The claim conditions for minting a token.
     *  @param price The price of minting one token.
     *  @param availableSupply The number of tokens that can be minted.
     *  @param allowlistMerkleRoot The allowlist of minters who are eligible to mint tokens
     */
    struct ClaimCondition {
        uint256 price;
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, ClaimCondition claimCondition);

    /// @notice Emitted when the next token ID to mint is updated.
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint when there is no more available supply to mint.
    error NotEnouthSupply(address token);

    /// @notice Emitted on an attempt to mint when incorrect msg value is sent.
    error IncorrectValueSent(uint256 msgValue, uint256 price);

    /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
    error NotInAllowlist(address token, address claimer);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the next token ID to mint.
    mapping(address => uint256) private _nextTokenIdToMint;

    /// @notice Mapping from token => the claim conditions for minting the token.
    mapping(address => ClaimCondition) public claimCondition;

    /// @notice Mapping from token => fee config for the token.
    mapping(address => FeeConfig) private feeConfig;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
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
        argSignature = "bytes32[]";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return _nextTokenIdToMint[_token];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return tokenIdToMint The token ID to start minting the given quantity tokens from.
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        override
        returns (uint256 tokenIdToMint)
    {
        address token = msg.sender;

        ClaimCondition memory condition = claimCondition[token];

        if (condition.availableSupply == 0) {
            revert NotEnouthSupply(token);
        }

        uint256 totalPrice = condition.price * _quantity;
        if (msg.value != totalPrice) {
            revert IncorrectValueSent(msg.value, totalPrice);
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert NotInAllowlist(token, _claimer);
            }
        }

        _collectPriceOnClaim(token, _quantity, condition.price);

        claimCondition[token].availableSupply -= _quantity;
        tokenIdToMint = _nextTokenIdToMint[token]++;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
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
     *  @notice Sets the fee config for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the fee config for.
     *  @param _config The fee config to set.
     */
    function setFeeConfig(address _token, FeeConfig calldata _config) external onlyAdmin(_token) {
        feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the claim condition for.
     *  @param _claimCondition The claim condition to set.
     */
    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public onlyAdmin(_token) {
        claimCondition[_token] = _claimCondition;
        emit ClaimConditionUpdate(_token, _claimCondition);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Transfers the sale price of minting based on the fee config set.
    function _collectPriceOnClaim(address _token, uint256 _quantityToClaim, uint256 _pricePerToken) internal {
        if (_pricePerToken == 0) {
            require(msg.value == 0, "!Value");
            return;
        }

        FeeConfig memory config = feeConfig[_token];

        uint256 totalPrice = _quantityToClaim * _pricePerToken;

        bool payoutPlatformFees = config.platformFeeBps > 0 && config.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if (payoutPlatformFees) {
            platformFees = (totalPrice * config.platformFeeBps) / 10_000;
        }

        require(msg.value == totalPrice, "!Price");
        if (payoutPlatformFees) {
            SafeTransferLib.safeTransferETH(config.platformFeeRecipient, platformFees);
        }
        SafeTransferLib.safeTransferETH(config.primarySaleRecipient, totalPrice - platformFees);
    }
}
