// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract HookFlagsDirectory {
    /// @notice Bits representing the beforeApproveForAll hook.
    uint256 public constant BEFORE_APPROVE_FOR_ALL_FLAG = 2 ** 1;

    /// @notice Bits representing the beforeApproveERC20 hook.
    uint256 public constant BEFORE_APPROVE_ERC20_FLAG = 2 ** 2;

    /// @notice Bits representing the beforeApproveERC721 hook.
    uint256 public constant BEFORE_APPROVE_ERC721_FLAG = 2 ** 3;

    /// @notice Bits representing the beforeBatchTransferERC1155 hook.
    uint256 public constant BEFORE_BATCH_TRANSFER_ERC1155_FLAG = 2 ** 4;

    /// @notice Bits representing the beforeBurnERC20 hook.
    uint256 public constant BEFORE_BURN_ERC20_FLAG = 2 ** 5;

    /// @notice Bits representing the beforeBurnERC721 hook.
    uint256 public constant BEFORE_BURN_ERC721_FLAG = 2 ** 6;

    /// @notice Bits representing the beforeBurnERC1155 hook.
    uint256 public constant BEFORE_BURN_ERC1155_FLAG = 2 ** 7;

    /// @notice Bits representing the beforeMintERC20 hook.
    uint256 public constant BEFORE_MINT_ERC20_FLAG = 2 ** 8;

    /// @notice Bits representing the beforeMintERC721 hook.
    uint256 public constant BEFORE_MINT_ERC721_FLAG = 2 ** 9;

    /// @notice Bits representing the beforeMintERC1155 hook.
    uint256 public constant BEFORE_MINT_ERC1155_FLAG = 2 ** 10;

    /// @notice Bits representing the beforeTransferERC20 hook.
    uint256 public constant BEFORE_TRANSFER_ERC20_FLAG = 2 ** 11;

    /// @notice Bits representing the beforeTransferERC721 hook.
    uint256 public constant BEFORE_TRANSFER_ERC721_FLAG = 2 ** 12;

    /// @notice Bits representing the beforeTransferERC1155 hook.
    uint256 public constant BEFORE_TRANSFER_ERC1155_FLAG = 2 ** 13;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ON_ROYALTY_INFO_FLAG = 2 ** 14;

    /// @notice Bits representing the token URI hook.
    uint256 public constant ON_TOKEN_URI_FLAG = 2 ** 15;
}
