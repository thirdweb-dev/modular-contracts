// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC721 } from  "./ERC721.sol";
import { BitMaps } from "./lib/BitMaps.sol";
import { Initializable } from "./extension/Initializable.sol";
import { Permissions } from "./extension/Permissions.sol";

interface ITokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract ERC721Core is Initializable, ERC721, Permissions {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMetadataSource(address indexed tokenMetadataSource);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant MINTER_ROLE = 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public tokenMetadataSource;
    uint256 public nextTokenIdToMint;

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address _defaultAdmin, address _tokenMetadataSource, string memory _name, string memory _symbol) external initializer {

        __ERC721_init(_name, _symbol);

        _hasRole[_defaultAdmin].set(ADMIN_ROLE);

        tokenMetadataSource = _tokenMetadataSource;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return ITokenURI(tokenMetadataSource).tokenURI(_tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address _to) external {
        if(!hasRole(msg.sender, MINTER_ROLE)) {
            revert Unauthorized(msg.sender, MINTER_ROLE);
        }
        _mint(_to, nextTokenIdToMint++);
    }

    function setTokenMetadataSource(address _tokenMetadataSource) external {
        if(!hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        tokenMetadataSource = _tokenMetadataSource;

        emit TokenMetadataSource(_tokenMetadataSource);
    }
}