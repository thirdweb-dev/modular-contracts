// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC721 } from  "./ERC721.sol";
import { ERC721Hooks } from "./ERC721Hooks.sol";
import { BitMaps } from "../lib/BitMaps.sol";
import { Initializable } from "../extension/Initializable.sol";
import { Permissions } from "../extension/Permissions.sol";

contract ERC721Core is Initializable, ERC721, ERC721Hooks, Permissions {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMinter(address indexed minter);

    /*//////////////////////////////////////////////////////////////
                               ERRROR
    //////////////////////////////////////////////////////////////*/

    error NotMinter(address caller);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public minter;
    uint256 public nextTokenIdToMint;

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address _defaultAdmin, string memory _name, string memory _symbol) external initializer {
        __ERC721_init(_name, _symbol);
        _hasRole[_defaultAdmin].set(ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 _tokenId) external burnHooks(msg.sender, _tokenId, "") {
        if(ownerOf(_tokenId) != msg.sender) {
            revert NotOwner(msg.sender, _tokenId);
        }

        _burn(_tokenId);
    }

    function mint(address _to) external mintHooks(_to, nextTokenIdToMint, "") {
        if(minter != msg.sender) {
            revert NotMinter(msg.sender);
        }
        _mint(_to, nextTokenIdToMint++);
    }

    function setMinter(address _minter) external {
        if(!hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        minter = _minter;

        emit TokenMinter(_minter);
    }

    function setHook(Hook _hook, address _implementation) external {
        if(!hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        _setHookImplementation(_implementation, _hook);   
    }

    function disableHook(Hook _hook) external {
        if(!hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        _diableHook(_hook);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override transferHooks(from, to, id, "") {
        super.transferFrom(from, to, id);
    }

    function approve(address spender, uint256 id) public override approveHooks(msg.sender, spender, id, "") {
        super.approve(spender, id);
    }
}