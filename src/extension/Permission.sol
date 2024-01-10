// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../lib/BitMaps.sol";
import "../interface/extension/IPermission.sol";

contract Permission is IPermission {
    using BitMaps for BitMaps.BitMap;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _permissionBits;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized(uint256 _roleBits) {
        if (!hasRole(msg.sender, _roleBits)) {
            revert PermissionUnauthorized(msg.sender, _roleBits);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasRole(address _account, uint256 _roleBits) public view returns (bool) {
        return _permissionBits[_account] & _roleBits > 0;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function grantRole(address _account, uint256 _roleBits) external onlyAuthorized(ADMIN_ROLE_BITS) {
        _setupRole(_account, _roleBits);
    }

    function revokeRole(address _account, uint256 _roleBits) external onlyAuthorized(ADMIN_ROLE_BITS) {
        _revokeRole(_account, _roleBits);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupRole(address _account, uint256 _roleBits) internal {
        uint256 permissions = _permissionBits[_account];
        permissions |= _roleBits;
        _permissionBits[_account] = permissions;

        emit PermissionUpdated(_account, _roleBits);
    }

    function _revokeRole(address _account, uint256 _roleBits) internal {
        uint256 permissions = _permissionBits[_account];
        permissions &= ~_roleBits;
        _permissionBits[_account] = permissions;

        emit PermissionUpdated(_account, permissions);
    }
}
