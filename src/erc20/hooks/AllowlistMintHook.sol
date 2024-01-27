// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IFeeConfig } from "../../interface/extension/IFeeConfig.sol";
import { IPermission } from "../../interface/extension/IPermission.sol";
import { ERC20Hook } from "./ERC20Hook.sol";
import { MerkleProofLib } from "../../lib/MerkleProofLib.sol";
import { SafeTransferLib } from "../../lib/SafeTransferLib.sol";

contract AllowlistMintHook is IFeeConfig, ERC20Hook {
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
  event ClaimConditionUpdate(
    address indexed token,
    ClaimCondition claimCondition
  );

  /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when caller is not token core admin.
  error AllowlistMintHookNotAuthorized();

  /// @notice Emitted on an attempt to mint when there is no more available supply to mint.
  error AllowlistMintHookNotEnoughSupply(address token);

  /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
  error AllowlistMintHookNotInAllowlist(address token, address claimer);

  /// @notice Emitted when incorrect native token value is sent.
  error AllowlistMintHookIncorrectValueSent();

  /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

  /// @notice The bits that represent the admin role.
  uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

  /// @notice The address considered as native token.
  address public constant NATIVE_TOKEN =
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @notice Mapping from token => the claim conditions for minting the token.
  mapping(address => ClaimCondition) public claimCondition;

  /// @notice Mapping from token => fee config for the token.
  mapping(address => FeeConfig) private _feeConfig;

  /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

  /// @notice Checks whether the caller is an admin of the given token.
  modifier onlyAdmin(address _token) {
    if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
      revert AllowlistMintHookNotAuthorized();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns all hook functions implemented by this hook contract.
  function getHooks()
    external
    pure
    returns (uint256 hooksImplemented)
  {
    hooksImplemented = BEFORE_MINT_FLAG;
  }

  /// @notice Returns the signature of the arguments expected by the beforeMint hook.
  function getBeforeMintArgSignature()
    external
    pure
    override
    returns (string memory argSignature)
  {
    argSignature = "bytes32[]";
  }

  /// @notice Returns the fee config for a token.
  function getFeeConfig(
    address _token
  ) external view returns (FeeConfig memory) {
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
   *  @return mintParams The details around which to execute a mint.
   */
  function beforeMint(
    address _claimer,
    uint256 _quantity,
    bytes memory _encodedArgs
  ) external payable override returns (MintParams memory mintParams) {
    address token = msg.sender;

    ClaimCondition memory condition = claimCondition[token];

    if (condition.availableSupply == 0) {
      revert AllowlistMintHookNotEnoughSupply(token);
    }

    if (condition.allowlistMerkleRoot != bytes32(0)) {
      bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

      bool isAllowlisted = MerkleProofLib.verify(
        allowlistProof,
        condition.allowlistMerkleRoot,
        keccak256(abi.encodePacked(_claimer))
      );
      if (!isAllowlisted) {
        revert AllowlistMintHookNotInAllowlist(token, _claimer);
      }
    }

    mintParams.quantityToMint = uint96(_quantity);
    mintParams.currency = NATIVE_TOKEN;
    // `price` is interpreted as price per 1 ether unit of the ERC20 tokens.
    mintParams.totalPrice = (_quantity * condition.price) / 1 ether;

    claimCondition[token].availableSupply -= _quantity;

    _collectPrice(mintParams.totalPrice);
  }

  /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice Sets the claim condition for a given token.
   *  @dev Only callable by an admin of the given token.
   *  @param _token The token to set the claim condition for.
   *  @param _claimCondition The claim condition to set.
   */
  function setClaimCondition(
    address _token,
    ClaimCondition memory _claimCondition
  ) public onlyAdmin(_token) {
    claimCondition[_token] = _claimCondition;
    emit ClaimConditionUpdate(_token, _claimCondition);
  }

  /**
   *  @notice Sets the fee config for a given token.
   *  @param _token The token address.
   *  @param _config The fee config for the token.
   */
  function setFeeConfig(
    address _token,
    FeeConfig memory _config
  ) external onlyAdmin(_token) {
    _feeConfig[_token] = _config;
    emit FeeConfigUpdate(_token, _config);
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function _collectPrice(uint256 _totalPrice) internal {
    if (msg.value != _totalPrice) {
      revert AllowlistMintHookIncorrectValueSent();
    }
    if (_totalPrice == 0) {
      return;
    }

    address token = msg.sender;
    FeeConfig memory feeConfig = _feeConfig[token];

    uint256 platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;

    if (msg.value != _totalPrice) {
      revert AllowlistMintHookIncorrectValueSent();
    }
    if (platformFees > 0) {
      SafeTransferLib.safeTransferETH(
        feeConfig.platformFeeRecipient,
        platformFees
      );
    }
    SafeTransferLib.safeTransferETH(
      feeConfig.primarySaleRecipient,
      _totalPrice - platformFees
    );
  }
}
