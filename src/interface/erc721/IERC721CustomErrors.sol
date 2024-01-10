// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

interface IERC721CustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to burn or query ownership of an unminted token.
    error ERC721NotMinted(uint256 tokenId);

    /// @notice Emitted on an attempt to mint a token that has already been minted.
    error ERC721AlreadyMinted(uint256 tokenId);

    /// @notice Emitted when an unapproved operator attempts to transfer or issue approval for a token.
    error ERC721NotApproved(address operator, uint256 tokenId);

    /// @notice Emitted on an attempt to transfer a token from non-owner's address.
    error ERC721NotOwner(address caller, uint256 tokenId);

    /// @notice Emitted on an attempt to mint or transfer a token to the zero address.
    error ERC721InvalidRecipient();

    /// @notice Emitted on an attempt to transfer a token to a contract not implementing ERC-721 Receiver interface.
    error ERC721UnsafeRecipient(address recipient);
}
