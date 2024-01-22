// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { IERC1155Hook } from "../../interface/erc1155/IERC1155Hook.sol";

abstract contract ERC1155Hook is IERC1155Hook {
  /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

  /// @notice Bits representing the before mint hook.
  uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

  /// @notice Bits representing the before transfer hook.
  uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

  /// @notice Bits representing the before burn hook.
  uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

  /// @notice Bits representing the before approve hook.
  uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

  /// @notice Bits representing the token URI hook.
  uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

  /// @notice Bits representing the royalty hook.
  uint256 public constant ROYALTY_INFO_FLAG = 2 ** 6;

  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns the signature of the arguments expected by the beforeMint hook.
  function getBeforeMintArgSignature()
    external
    view
    virtual
    returns (string memory argSignature)
  {
    argSignature = "";
  }

  /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function beforeMint(
    address _to,
    uint256 _id,
    uint256 _value,
    bytes memory _encodedArgs
  ) external payable virtual returns (MintParams memory details) {
    revert ERC1155HookNotImplemented();
  }

  function beforeTransfer(
    address _from,
    address _to,
    uint256 _id,
    uint256 _value
  ) external virtual {
    revert ERC1155HookNotImplemented();
  }

  function beforeBurn(
    address _from,
    uint256 _id,
    uint256 _value
  ) external virtual {
    revert ERC1155HookNotImplemented();
  }

  function beforeApprove(
    address _from,
    address _to,
    bool _approved
  ) external virtual {
    revert ERC1155HookNotImplemented();
  }

  function uri(
    uint256 id
  ) external view virtual returns (string memory metadata) {
    revert ERC1155HookNotImplemented();
  }

  function royaltyInfo(
    uint256 id,
    uint256 salePrice
  ) external view virtual returns (address receiver, uint256 royaltyAmount) {
    revert ERC1155HookNotImplemented();
  }
}
