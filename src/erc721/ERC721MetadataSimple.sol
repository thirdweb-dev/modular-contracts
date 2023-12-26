// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { BitMaps } from "../lib/BitMaps.sol";
import { Permissions } from "../extension/Permissions.sol";

contract ERC721MetadataSimple {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               Events
    //////////////////////////////////////////////////////////////*/

    event TokenMetadataSet(address indexed token, uint256 indexed tokenId, string uri);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, address token);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address public tokenAddress;

    mapping(uint256 => string) private _tokenURI;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {
        return _tokenURI[_tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                        PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTokenURI(address _token, uint256 _tokenId, string memory _uri) public {
        // Check for admin role
        if(!Permissions(_token).hasRole(msg.sender, 0)) {
            revert Unauthorized(msg.sender, _token);
        }
        _tokenURI[_tokenId] = _uri;

        emit TokenMetadataSet(_token, _tokenId, _uri);
    }
}