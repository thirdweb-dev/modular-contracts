// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { IERC20Hook } from "../../interface/erc20/IERC20Hook.sol";

abstract contract ERC20Hook is IERC20Hook {
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
    uint256 _amount,
    bytes memory _encodedArgs
  ) external payable virtual returns (MintParams memory details) {
    revert ERC20HookNotImplemented();
  }

  function beforeTransfer(
    address _from,
    address _to,
    uint256 _amount
  ) external virtual {
    revert ERC20HookNotImplemented();
  }

  function beforeBurn(address _from, uint256 _amount) external virtual {
    revert ERC20HookNotImplemented();
  }

  function beforeApprove(
    address _from,
    address _to,
    uint256 _amount
  ) external virtual {
    revert ERC20HookNotImplemented();
  }
}
