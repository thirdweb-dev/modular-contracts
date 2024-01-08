// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../eip/IERC165.sol";

interface IERC721 is IERC165 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ERC721NotMinted(uint256 tokenId);
    error ERC721AlreadyMinted(uint256 tokenId);
    error ERC721NotApproved(address operator, uint256 tokenId);
    error ERC721NotOwner(address caller, uint256 tokenId);
    error ERC721InvalidRecipient();
    error ERC721UnsafeRecipient(address recipient);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function ownerOf(uint256 id) external view returns (address owner);

    function balanceOf(address owner) external view returns (uint256);

    function getApproved (uint256 id) external view returns (address);

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) external;

    function setApprovalForAll(address operator, bool approved) external;

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external;
}