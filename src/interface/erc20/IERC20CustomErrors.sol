// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20CustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when burning or approving tokens from zero address as owner.
    error ERC20FromZeroAddress(address owner, uint256 amount);

    /// @notice Emitted when minting or approving tokens to zero address as spender.
    error ERC20ToZeroAddress(address spender, uint256 amount);

    /// @notice Emitted when a spender transfers more tokens than their allowance.
    error ERC20InsufficientAllowance(uint256 allowance, uint256 amount);

    /// @notice Emitted on token transfer to zero address.
    error ERC20TransferToZeroAddress();

    /// @notice Emitted on token transfer from zero address.
    error ERC20TransferFromZeroAddress();

    /// @notice Emitted when transfer amount exceeds balance.
    error ERC20TransferAmountExceedsBalance(uint256 amount, uint256 balance);
}
