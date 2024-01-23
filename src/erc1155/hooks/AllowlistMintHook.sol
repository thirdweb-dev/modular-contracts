// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IFeeConfig } from "../../interface/extension/IFeeConfig.sol";
import { IPermission } from "../../interface/extension/IPermission.sol";
import { ERC1155Hook } from "./ERC1155Hook.sol";
import { MerkleProofLib } from "../../lib/MerkleProofLib.sol";
import { SafeTransferLib } from "../../lib/SafeTransferLib.sol";

contract AllowlistMintHook is IFeeConfig, ERC1155Hook {
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
    uint256 id,
    ClaimCondition claimCondition
  );

  /// @notice Emitted when the next token ID to mint is updated.
  event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

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

  /// @notice Mapping from token => token-id => the claim conditions for minting the token.
  mapping(address => mapping(uint256 => ClaimCondition)) public claimCondition;

  /// @notice Mapping from token => token-id => fee config for the token.
  mapping(address => mapping(uint256 => FeeConfig)) private _feeConfig;

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
  function getHooksImplemented()
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
  function getFeeConfigForToken(
    address _token,
    uint256 _id
  ) external view returns (FeeConfig memory) {
    return _feeConfig[_token][_id];
  }

  /// @notice Returns the fee config for a token.
  function getDefaultFeeConfig(
    address _token
  ) external view returns (FeeConfig memory) {
    return _feeConfig[_token][type(uint256).max];
  }

  /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

  function beforeMint(
    address _claimer,
    uint256 _id,
    uint256 _value,
    bytes memory _encodedArgs
  ) external payable override returns (MintParams memory mintParams) {
    address token = msg.sender;

    ClaimCondition memory condition = claimCondition[token][_id];

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

    mintParams.quantityToMint = uint96(_value);
    mintParams.currency = NATIVE_TOKEN;
    mintParams.totalPrice = _value * condition.price;
    mintParams.idToMint = _id;

    claimCondition[token][_id].availableSupply -= _value;

    _collectPrice(mintParams.totalPrice, _id);
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
    uint256 _id,
    ClaimCondition memory _claimCondition
  ) public onlyAdmin(_token) {
    claimCondition[_token][_id] = _claimCondition;
    emit ClaimConditionUpdate(_token, _id, _claimCondition);
  }

  /**
   *  @notice Sets the fee config for a given token.
   *  @param _token The token address.
   *  @param _config The fee config for the token.
   */
  function setFeeConfigForToken(
    address _token,
    uint256 _id,
    FeeConfig memory _config
  ) external onlyAdmin(_token) {
    _feeConfig[_token][_id] = _config;
    emit FeeConfigUpdateERC1155(_token, _id, _config);
  }

  /**
   *  @notice Sets the fee config for a given token.
   *  @param _token The token address.
   *  @param _config The fee config for the token.
   */
  function setDefaultFeeConfig(
    address _token,
    FeeConfig memory _config
  ) external onlyAdmin(_token) {
    _feeConfig[_token][type(uint256).max] = _config;
    emit FeeConfigUpdateERC1155(_token, type(uint256).max, _config);
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function _collectPrice(uint256 _totalPrice, uint256 _id) internal {
    if (msg.value != _totalPrice) {
      revert AllowlistMintHookIncorrectValueSent();
    }
    if (_totalPrice == 0) {
      return;
    }

    address token = msg.sender;
    FeeConfig memory feeConfig = _feeConfig[token][_id];

    if (
      feeConfig.primarySaleRecipient == address(0) &&
      feeConfig.platformFeeRecipient == address(0)
    ) {
      feeConfig = _feeConfig[token][type(uint256).max];
    }

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
