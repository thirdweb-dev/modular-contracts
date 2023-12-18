// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../lib/BitMaps.sol";

contract Permissions {
    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event RoleGranted(address indexed account, uint8 role);
    event RoleRevoked(address indexed account, uint8 role);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, uint8 role);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint8 public constant ADMIN_ROLE = 0;

    mapping(address => BitMaps.BitMap) private _hasRole;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasRole(address _account, uint8 _role) external view returns (bool) {
        return _hasRole[_account].get(_role);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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