// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ITokenHook} from "../interface/extension/ITokenHook.sol";

abstract contract TokenHook is ITokenHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_INFO_FLAG = 2 ** 6;

    /// @notice Bits representing the sale value distribution hook.
    uint256 public constant DISTRIBUTE_SALE_VALUE_FLAG = 2 ** 7;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _to The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return details The details around which to execute a mint.
     */
    function beforeMint(address _to, uint256 _quantity, bytes memory _encodedArgs)
        external
        virtual
        returns (MintParams memory details)
    {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _tokenId The token ID being transferred.
     */
    function beforeTransfer(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param _from The address that is burning tokens.
     *  @param _tokenId The token ID being burned.
     */
    function beforeBurn(address _from, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _tokenId The token ID being approved.
     */
    function beforeApprove(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch token metadata from.
     */
    function tokenURI(uint256 tokenId) external view virtual returns (string memory metadata) {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice Returns the royalty recipient and amount for a given sale.
     *  @dev Meant to be called by a token contract.
     *  @param tokenId The token ID of the NFT.
     *  @param salePrice The sale price of the NFT.
     *  @return receiver The royalty recipient address.
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view virtual returns (address receiver, uint256 royaltyAmount) {
        revert TokenHookNotImplemented();
    }

    /**
     *  @notice Distributes the sale value of a mint.
     *  @param minter The address of the claimer.
     *  @param totalPrice The total price of the mint.
     *  @param currency The currency in which the sale was made.
     */
    function distributeSaleValue(address minter, uint256 totalPrice, address currency) external payable virtual {
        revert TokenHookNotImplemented();
    }
}

contract TokenHookExample is TokenHook {
    event SomeEvent();

    uint256 private _nextId;

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | BEFORE_BURN_FLAG;
    }

    function beforeMint(address, uint256, bytes memory) external override returns (MintParams memory details) {
        details.tokenIdToMint = _nextId++;
        emit SomeEvent();
    }

    function beforeBurn(address, uint256) external override {
        emit SomeEvent();
    }
}
