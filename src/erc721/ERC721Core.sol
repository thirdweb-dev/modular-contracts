// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC721 } from  "./ERC721.sol";
import { TokenHookConsumer } from "./TokenHookConsumer.sol";
import { BitMaps } from "../lib/BitMaps.sol";
import { Initializable } from "../extension/Initializable.sol";
import { Permission } from "../extension/Permission.sol";

contract ERC721Core is Initializable, ERC721, TokenHookConsumer, Permission {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMinter(address indexed minter);

    /*//////////////////////////////////////////////////////////////
                               ERRROR
    //////////////////////////////////////////////////////////////*/

    error ERC721CoreMintNotAuthorized();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextTokenIdToMint;

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
        if(owner != msg.sender) {
            revert ERC721NotOwner(msg.sender, _tokenId);
        }

        _beforeBurn(owner, _tokenId);

        _burn(_tokenId);

        _afterBurn(owner, _tokenId);
    }

    function mint(address _to, bytes memory _data) external payable {

        (bool success, uint256 tokenIdToMint) = _beforeMint(_to, _data);

        if(success) {
            _mint(_to, tokenIdToMint, address(0));
            _afterMint(_to, tokenIdToMint);
            return;
        }

        revert ERC721CoreMintNotAuthorized();
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        _beforeTransfer(from, to, id);
        super.transferFrom(from, to, id);
        _afterTransfer(from, to, id);
    }

    function approve(address spender, uint256 id) public override {
        _beforeApprove(msg.sender, spender, id);
        super.approve(spender, id);
        _afterApprove(msg.sender, spender, id);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
    }
}