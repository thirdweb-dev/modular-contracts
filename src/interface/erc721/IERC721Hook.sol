// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extension/IHook.sol";

interface IERC721Hook is IHook {

    /*//////////////////////////////////////////////////////////////
                                STRUCT
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice A struct for internal use. The details around which to execute a mint, returned by the beforeMint hook.
     *  @param tokenIdToMint The token ID to start minting the given quantity tokens from.
     *  @param totalPrice The total price to pay to mint the tokens.
     *  @param currency The currency in which to pay for the tokens.
     *  @param quantityToMint The quantity of tokens to mint.
     */
    struct MintParams {
        uint256 tokenIdToMint;
        uint256 totalPrice;
        address currency;
        uint96 quantityToMint;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to call a hook that is not implemented.
    error ERC721HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external view returns (string memory argSignature);

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param to The address that is minting tokens.
     *  @param quantity The quantity of tokens to mint.
     *  @param encodedArgs The encoded arguments for the beforeMint hook.
     *  @return details The details around which to execute a mint.
     */
    function beforeMint(address to, uint256 quantity, bytes memory encodedArgs)
        external
        payable
        returns (MintParams memory details);

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param from The address that is transferring tokens.
     *  @param to The address that is receiving tokens.
     *  @param tokenId The token ID being transferred.
     */
    function beforeTransfer(address from, address to, uint256 tokenId) external;

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param from The address that is burning tokens.
     *  @param tokenId The token ID being burned.
     */
    function beforeBurn(address from, uint256 tokenId) external;

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param from The address that is approving tokens.
     *  @param to The address that is being approved.
     *  @param tokenId The token ID being approved.
     */
    function beforeApprove(address from, address to, uint256 tokenId) external;

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
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}
