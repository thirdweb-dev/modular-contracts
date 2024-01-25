// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20CoreCustomErrors {
  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
  error ERC20CoreMintingDisabled();

  error ERC20CorePermitDisabled();

  error ERC20PermitInvalidSigner();

  error ERC20PermitDeadlineExpired();
}