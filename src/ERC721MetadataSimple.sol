// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { BitMaps } from "./lib/BitMaps.sol";
import { Permissions } from "./extension/Permissions.sol";

contract ERC721MetadataSimple is Permissions {

    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant METADATA_ROLE = 2;

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
}