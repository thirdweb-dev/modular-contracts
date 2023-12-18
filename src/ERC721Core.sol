// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC721 } from  "./ERC721.sol";
import { BitMaps } from "./BitMaps.sol";

interface ITokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract ERC721Core is ERC721 {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event RoleGranted(address indexed account, uint8 indexed role);
    event RoleRevoked(address indexed account, uint8 indexed role);
    event TokenMetadataSource(address indexed tokenMetadataSource);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, uint8 role);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant ADMIN_ROLE = 0;
    uint8 public constant MINTER_ROLE = 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public tokenMetadataSource;
    uint256 public nextTokenIdToMint;
    mapping(address => BitMaps.BitMap) private _hasRole;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        _hasRole[msg.sender].set(ADMIN_ROLE);
        _hasRole[msg.sender].set(MINTER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return ITokenURI(tokenMetadataSource).tokenURI(_tokenId);
    }

    function hasRole(address _account, uint8 _role) external view returns (bool) {
        return _hasRole[_account].get(_role);
    }

    /*//////////////////////////////////////////////////////////////
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address _to) external {
        if(!_hasRole[msg.sender].get(MINTER_ROLE)) {
            revert Unauthorized(msg.sender, MINTER_ROLE);
        }
        _mint(_to, ++nextTokenIdToMint);
    }

    function grantRole(address _account, uint8 _role) external {
        if(!_hasRole[msg.sender].get(ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        _hasRole[_account].set(_role);

        emit RoleGranted(_account, _role);
    }

    function revokeRole(address _account, uint8 _role) external {
        if(!_hasRole[msg.sender].get(ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        _hasRole[_account].unset(_role);

        emit RoleRevoked(_account, _role);
    }

    function setTokenMetadataSource(address _tokenMetadataSource) external {
        if(!_hasRole[msg.sender].get(ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        tokenMetadataSource = _tokenMetadataSource;

        emit TokenMetadataSource(_tokenMetadataSource);
    }
}