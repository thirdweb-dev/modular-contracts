// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "./IHook.sol";
import {IMintRequest} from "../common/IMintRequest.sol";
import {IBurnRequest} from "../common/IBurnRequest.sol";

interface IERC721Hook is IHook, IMintRequest, IBurnRequest {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to call a hook that is not implemented.
    error ERC721HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param mintRequest The token mint request details.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata mintRequest)
        external
        payable
        returns (uint256 tokenIdToMint, uint256 quantityToMint);

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param from The address that is transferring tokens.
     *  @param to The address that is receiving tokens.
     *  @param tokenId The token ID being transferred.
     */
    function beforeTransfer(address from, address to, uint256 tokenId) external;

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param burnRequest The token burn request details.
     */
    function beforeBurn(BurnRequest calldata burnRequest) external;

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param from The address that is approving tokens.
     *  @param to The address that is being approved.
     *  @param tokenId The token ID being approved.
     *  @param approve The approval status to set.
     */
    function beforeApprove(address from, address to, uint256 tokenId, bool approve) external;

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch token metadata from.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory metadata);

    /**
     *  @notice Returns the royalty recipient and amount for a given sale.
     *  @dev Meant to be called by a token contract.
     *  @param tokenId The token ID of the NFT.
     *  @param salePrice The sale price of the NFT.
     *  @return receiver The royalty recipient address.
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
