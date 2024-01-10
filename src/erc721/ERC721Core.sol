// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IERC721Metadata} from "../interface/erc721/IERC721Metadata.sol";
import { IERC2981 } from "../interface/eip/IERC2981.sol";
import {ERC721Initializable} from "./ERC721Initializable.sol";
import {NFTHookConsumer} from "../extension/NFTHookConsumer.sol";
import {Initializable} from "../extension/Initializable.sol";
import {Permission} from "../extension/Permission.sol";

contract ERC721Core is Initializable, ERC721Initializable, NFTHookConsumer,  Permission {

    /*//////////////////////////////////////////////////////////////
                               ERRROR 
    //////////////////////////////////////////////////////////////*/

    error ERC721CoreMintNotAuthorized();

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

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
        return IERC721Metadata(
            getHookImplementation(TOKEN_URI_FLAG)
        ).tokenURI(_id);
    }

    /**
     *  @notice Returns the royalty amount for a given NFT and sale price.
     *  @param _tokenId The token ID of the NFT
     *  @param _salePrice The sale price of the NFT
     *  @return recipient The royalty recipient address
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address recipient, uint256 royaltyAmount) {
        (recipient, royaltyAmount) =  IERC2981(
            getHookImplementation(ROYALTY_FLAG)
        ).royaltyInfo(_tokenId, _salePrice);
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
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 _tokenId) external {
        address owner = ownerOf(_tokenId);
        if (owner != msg.sender) {
            revert ERC721NotOwner(msg.sender, _tokenId);
        }

        _beforeBurn(owner, _tokenId);
        _burn(_tokenId);
    }

    function mint(address _to, uint256 _quantity, bytes memory _data) external payable {
        (bool success, address metadataSource, uint256 tokenIdToMint) = _beforeMint(_to, _quantity, _data);

        if (success) {
            _mint(_to, tokenIdToMint, _quantity, metadataSource);
            return;
        }

        revert ERC721CoreMintNotAuthorized();
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFrom(address _from, address _to, uint256 _id) public override {
        _beforeTransfer(_from, _to, _id);
        super.transferFrom(_from, _to, _id);
    }

    function approve(address _spender, uint256 _id) public override {
        _beforeApprove(msg.sender, _spender, _id);
        super.approve(_spender, _id);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
    }
}
