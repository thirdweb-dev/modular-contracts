// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20CoreCustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
    error ERC20CoreMintingDisabled();

    /// @notice Emitted when an unauthorized signer permits a spender to spend on an owner's their behalf.
    error ERC20PermitInvalidSigner();

    /// @notice Emitted on an attempt to permit approve tokens past the permit deadline.
    error ERC20PermitDeadlineExpired();

    /// @notice Emitted on a failed attempt to initialize the contract.
    error ERC20CoreInitializationFailed();
}
