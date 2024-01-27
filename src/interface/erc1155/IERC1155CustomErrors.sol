// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC1155CustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an unapproved operator attempts to transfer or issue approval for a token.
    error ERC1155NotApprovedOrOwner(address operator);

    /// @notice Emitted on an attempt to transfer a token when insufficient balance.
    error ERC1155NotBalance(address caller, uint256 id, uint256 value);

    /// @notice Emitted on an attempt to mint or transfer a token to the zero address.
    error ERC1155InvalidRecipient();

    /// @notice Emitted on an attempt to transfer a token to a contract not implementing ERC-1155 Receiver interface.
    error ERC1155UnsafeRecipient(address recipient);

    error ERC1155ArrayLengthMismatch();

    error ERC1155BurnFromZeroAddress();
}
