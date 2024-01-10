// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC721Initializable} from "./ERC721Initializable.sol";
import {TokenHookConsumer} from "../extension/TokenHookConsumer.sol";
import {BitMaps} from "../lib/BitMaps.sol";
import {Initializable} from "../extension/Initializable.sol";
import {Permission} from "../extension/Permission.sol";

contract ERC721Core is Initializable, ERC721Initializable, TokenHookConsumer, Permission {
    using BitMaps for BitMaps.BitMap;

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
