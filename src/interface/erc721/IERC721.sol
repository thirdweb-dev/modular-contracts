// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../eip/IERC165.sol";

interface IERC721 is IERC165 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on a successful token transfer.
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    /// @notice Emitted when a token owner approves a spender to transfer or issue approval for a specific token.
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    /// @notice Emitted when a token owner approves a spender to transfer or issue approval for any of their tokens.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the owner of an NFT. Reverts if no owner.
     *  @param id The token ID of the NFT
     *  @return owner The address of the owner of the NFT
     */
    function ownerOf(uint256 id) external view returns (address owner);

    /**
     *  @notice Returns the total quantity of NFTs owned by an address.
     *  @param owner The address to query the balance of
     *  @return balance The number of NFTs owned by the queried address
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     *  @notice Returns the single address approved to transfer an NFT. Returns address(0) if no one is approved.
     *  @param id The token ID of the NFT
     *  @return operator The address approved to transfer the NFT
     */
    function getApproved(uint256 id) external view returns (address operator);

    /**
     *  @notice Returns whether operator is approved to transfer or issue approval of any of the owner's NFTs.
     *  @param owner The address that owns the NFTs
     *  @param operator The address to check the approval of
     *  @return approved Whether the operator is approved to transfer or issue approval of any of the owner's NFTs
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @param spender The address to approve
     *  @param id The token ID of the NFT
     */
    function approve(address spender, uint256 id) external;

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param operator The address to approve or revoke approval from
     *  @param approved Whether the operator is approved
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param id The token ID of the NFT
     */
    function transferFrom(address from, address to, uint256 id) external;

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param id The token ID of the NFT
     */
    function safeTransferFrom(address from, address to, uint256 id) external;

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param id The token ID of the NFT
     *  @param data Additional data passed onto the `onERC721Received` call to the recipient
     */
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) external;
}
