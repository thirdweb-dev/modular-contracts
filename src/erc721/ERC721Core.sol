// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IERC721Metadata} from "../interface/erc721/IERC721Metadata.sol";
import {IERC2981} from "../interface/eip/IERC2981.sol";
import {IERC721CoreCustomErrors} from "../interface/erc721/IERC721CoreCustomErrors.sol";
import {ERC721Initializable} from "./ERC721Initializable.sol";
import {TokenHookConsumer} from "../extension/TokenHookConsumer.sol";
import {Initializable} from "../extension/Initializable.sol";
import {Permission} from "../extension/Permission.sol";

contract ERC721Core is Initializable, ERC721Initializable, TokenHookConsumer, Permission, IERC721CoreCustomErrors {
    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     *  @notice Initializes the ERC-721 Core contract.
     *  @param _defaultAdmin The default admin for the contract.
     *  @param _name The name of the token collection.
     *  @param _symbol The symbol of the token collection.
     */
    function initialize(address _defaultAdmin, string memory _name, string memory _symbol) external initializer {
        __ERC721_init(_name, _symbol);
        _setupRole(_defaultAdmin, ADMIN_ROLE_BITS);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _id The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function tokenURI(uint256 _id) public view returns (string memory) {
        return IERC721Metadata(getHookImplementation(TOKEN_URI_FLAG)).tokenURI(_id);
    }

    /**
     *  @notice Returns the royalty amount for a given NFT and sale price.
     *  @param _tokenId The token ID of the NFT
     *  @param _salePrice The sale price of the NFT
     *  @return recipient The royalty recipient address
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address recipient, uint256 royaltyAmount)
    {
        (recipient, royaltyAmount) = IERC2981(getHookImplementation(ROYALTY_FLAG)).royaltyInfo(_tokenId, _salePrice);
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public pure override returns (bool) {
        return _interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || _interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || _interfaceId == 0x5b5e139f // ERC165 Interface ID for ERC721Metadata
            || _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Burns an NFT.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _tokenId The token ID of the NFT to burn.
     */
    function burn(uint256 _tokenId) external {
        address owner = ownerOf(_tokenId);
        if (owner != msg.sender) {
            revert ERC721NotOwner(msg.sender, _tokenId);
        }

        _beforeBurn(owner, _tokenId);
        _burn(_tokenId);
    }

    /**
     *  @notice Mints a token. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the token to.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(address _to, uint256 _quantity, bytes memory _encodedBeforeMintArgs) external payable {
        (bool success, uint256 tokenIdToMint) = _beforeMint(_to, _quantity, _encodedBeforeMintArgs);

        if (success) {
            _mint(_to, tokenIdToMint, _quantity);
            return;
        }

        revert ERC721CoreMintingDisabled();
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(address _from, address _to, uint256 _id) public override {
        _beforeTransfer(_from, _to, _id);
        super.transferFrom(_from, _to, _id);
    }

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param _spender The address to approve
     *  @param _id The token ID of the NFT
     */
    function approve(address _spender, uint256 _id) public override {
        _beforeApprove(msg.sender, _spender, _id);
        super.approve(_spender, _id);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the given caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
    }
}
