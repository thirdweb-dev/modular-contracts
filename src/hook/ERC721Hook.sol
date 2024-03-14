// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "@solady/utils/Initializable.sol";
import "@solady/utils/UUPSUpgradeable.sol";
import "@solady/auth/Ownable.sol";

import {IERC721Hook} from "../interface/hook/IERC721Hook.sol";

abstract contract ERC721Hook is Initializable, UUPSUpgradeable, Ownable, IERC721Hook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    function BEFORE_MINT_FLAG() public pure virtual returns (uint256) {
        return 2 ** 1;
    }

    /// @notice Bits representing the before transfer hook.
    function BEFORE_TRANSFER_FLAG() public pure virtual returns (uint256) {
        return 2 ** 2;
    }

    /// @notice Bits representing the before burn hook.
    function BEFORE_BURN_FLAG() public pure virtual returns (uint256) {
        return 2 ** 3;
    }

    /// @notice Bits representing the before approve hook.
    function BEFORE_APPROVE_FLAG() public pure virtual returns (uint256) {
        return 2 ** 4;
    }

    /// @notice Bits representing the token URI hook.
    function ON_TOKEN_URI_FLAG() public pure virtual returns (uint256) {
        return 2 ** 5;
    }

    /// @notice Bits representing the royalty hook.
    function ON_ROYALTY_INFO_FLAG() public pure virtual returns (uint256) {
        return 2 ** 6;
    }

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    error ERC721UnauthorizedUpgrade();

    /*//////////////////////////////////////////////////////////////
                     CONSTRUCTOR & INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract. Grants admin role (i.e. upgrade authority) to given `_upgradeAdmin`.
    function __ERC721Hook_init(address _upgradeAdmin) public onlyInitializing {
        _setOwner(_upgradeAdmin);
    }

    /// @notice Checks if `msg.sender` is authorized to upgrade the proxy to `newImplementation`, reverting if not.
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != owner()) {
            revert ERC721UnauthorizedUpgrade();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
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
        virtual
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        revert ERC721HookNotImplemented();
    }

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _tokenId The token ID being transferred.
     */
    function beforeTransfer(address _from, address _to, uint256 _tokenId) external virtual {
        revert ERC721HookNotImplemented();
    }

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param burnRequest The token burn request details.
     */
    function beforeBurn(BurnRequest calldata burnRequest) external virtual {
        revert ERC721HookNotImplemented();
    }

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _tokenId The token ID being approved.
     *  @param _approve The approval status to set.
     */
    function beforeApprove(address _from, address _to, uint256 _tokenId, bool _approve) external virtual {
        revert ERC721HookNotImplemented();
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch token metadata from.
     */
    function onTokenURI(uint256 tokenId) external view virtual returns (string memory metadata) {
        revert ERC721HookNotImplemented();
    }

    /**
     *  @notice Returns the royalty recipient and amount for a given sale.
     *  @dev Meant to be called by a token contract.
     *  @param tokenId The token ID of the NFT.
     *  @param salePrice The sale price of the NFT.
     *  @return receiver The royalty recipient address.
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale.
     */
    function onRoyaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        revert ERC721HookNotImplemented();
    }
}
