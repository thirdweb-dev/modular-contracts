// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { BitMaps } from "./lib/BitMaps.sol";

contract ERC721MetadataSimple {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event RoleGranted(address indexed account, uint8 indexed role);
    event RoleRevoked(address indexed account, uint8 indexed role);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, uint8 role);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant ADMIN_ROLE = 0;
    uint8 public constant METADATA_ROLE = 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public tokenAddress;

    mapping(uint256 => string) private _tokenURI;
    mapping(address => BitMaps.BitMap) private _hasRole;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {
        return _tokenURI[_tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTokenURI(uint256 _tokenId, string memory _uri) public {
        if(!_hasRole[msg.sender].get(METADATA_ROLE)) {
            revert Unauthorized(msg.sender, METADATA_ROLE);
        }
        _tokenURI[_tokenId] = _uri;
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
}