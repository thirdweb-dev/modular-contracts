// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20CustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ERC20FromZeroAddress(address owner, uint256 amount);

    error ERC20ToZeroAddress(address spender, uint256 amount);

    error ERC20InsufficientAllowance(uint256 allowance, uint256 amount);

    error ERC20TransferToZeroAddress();

    error ERC20TransferFromZeroAddress();

    error ERC20TransferAmountExceedsBalance(uint256 amount, uint256 balance);
}
