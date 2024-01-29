// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IERC1155Hook} from "../../interface/erc1155/IERC1155Hook.sol";

abstract contract ERC1155Hook is IERC1155Hook {
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
     *  @param _id The token ID being minted.
     *  @param _value The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(address _to, uint256 _id, uint256 _value, bytes memory _encodedArgs)
        external
        payable
        virtual
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        revert ERC1155HookNotImplemented();
    }

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _id The token ID being transferred.
     *  @param _value The quantity of tokens being transferred.
     */
    function beforeTransfer(address _from, address _to, uint256 _id, uint256 _value) external virtual {
        revert ERC1155HookNotImplemented();
    }

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param _from The address that is burning tokens.
     *  @param _id The token ID being burned.
     *  @param _value The quantity of tokens being burned.
     */
    function beforeBurn(address _from, uint256 _id, uint256 _value) external virtual {
        revert ERC1155HookNotImplemented();
    }

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _approved Whether to grant or revoke approval.
     */
    function beforeApprove(address _from, address _to, bool _approved) external virtual {
        revert ERC1155HookNotImplemented();
    }

    /**
     *  @notice The uri hook that is called by a core token to retrieve the URI for a token.
     *  @param _id The token ID to retrieve the URI for.
     *  @return metadata The URI for the token.
     */
    function uri(uint256 _id) external view virtual returns (string memory metadata) {
        revert ERC1155HookNotImplemented();
    }

    /**
     *  @notice The royaltyInfo hook that is called by a core token to retrieve the royalty information for a token.
     *  @param _id The token ID to retrieve the royalty information for.
     *  @param _salePrice The sale price of the token.
     *  @return receiver The address to send the royalty payment to.
     *  @return royaltyAmount The amount of royalty to pay.
     */
    function royaltyInfo(uint256 _id, uint256 _salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        revert ERC1155HookNotImplemented();
    }
}
