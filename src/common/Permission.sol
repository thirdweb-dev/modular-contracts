// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IPermission } from "../interface/common/IPermission.sol";
import { PermissionStorage } from "../storage/common/PermissionStorage.sol";

contract Permission is IPermission {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts if the caller does not have the given permissions.
    modifier onlyAuthorized(uint256 _roleBits) {
        if (!hasRole(msg.sender, _roleBits)) {
            revert PermissionUnauthorized(msg.sender, _roleBits);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns whether an account has the given permissions.
     *  @param _account The account to check.
     *  @param _roleBits The bits representing the permissions to check.
     *  @return hasPermissions Whether the account has the given permissions.
     */
    function hasRole(address _account, uint256 _roleBits) public view returns (bool) {
        return PermissionStorage.data().permissionBits[_account] & _roleBits > 0;
    }

    /// @notice Returns the total number of accounts who have any permissions.
    function getRoleMemberCount() external view returns (uint256) {
        return PermissionStorage.data().roleMemberCount;
    }

    /// @notice Returns the number of accounts who hold the given permissions.
    function getRoleMemberCount(uint256 _roleBits) external view returns (uint256 count) {
        PermissionStorage.Data storage data = PermissionStorage.data();
        
        uint256 len = data.roleMemberCount;       
        for (uint256 i = 1; i < (1 + len); i++) {
            if (hasRole(data.memberAtIndex[i], _roleBits)) {
                count++;
            }
        }
    }

    /**
     *  @notice Returns all holders with the given permissions, within the given range.
     *  @param _roleBits The bits representing the permissions to check.
     *  @param _startIndex The start index of the range. (inclusive)
     *  @param _endIndex The end index of the range. (non-inclusive)
     *  @return hodlers The holders with the given permissions, within the given range.
     */
    function getRoleMembers(uint256 _roleBits, uint256 _startIndex, uint256 _endIndex) external view returns (address[] memory hodlers) {
        PermissionStorage.Data storage data = PermissionStorage.data();
        
        uint256 len = data.roleMemberCount;
        if(_endIndex >= _startIndex || _endIndex > len) {
            revert PermissionInvalidRange();
        }
        
        uint256 count = 0;
        for (uint256 i = (1 + _startIndex); i < (1 + _endIndex); i++) {
            if (hasRole(data.memberAtIndex[i], _roleBits)) {
                count++;
            }
        }

        hodlers = new address[](count);
        uint256 idx = 0; 

        for (uint256 j = 0; j < len; j++) {
            address holder = data.memberAtIndex[j];
            
            if (hasRole(holder, _roleBits)) {
                hodlers[idx] = holder;
                idx++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Grants the given permissions to an account.
     *  @param _account The account to grant permissions to.
     *  @param _roleBits The bits representing the permissions to grant.
     */
    function grantRole(address _account, uint256 _roleBits) external onlyAuthorized(ADMIN_ROLE_BITS) {
        _setupRole(_account, _roleBits);
    }

    /**
     *  @notice Revokes the given permissions from an account.
     *  @param _account The account to revoke permissions from.
     *  @param _roleBits The bits representing the permissions to revoke.
     */
    function revokeRole(address _account, uint256 _roleBits) external onlyAuthorized(ADMIN_ROLE_BITS) {
        _revokeRole(_account, _roleBits);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Assigns the given permissions to an account, without checking the permissions of the caller.
    function _setupRole(address _account, uint256 _roleBits) internal {
        PermissionStorage.Data storage data = PermissionStorage.data();

        if(data.indexOfMember[_account] == 0 && _roleBits > 0) {
            // Increment the count and then assign, so that index is never 0.
            uint256 idx = ++data.roleMemberCount;
            data.memberAtIndex[idx] = _account;
            data.indexOfMember[_account] = idx;
        }

        uint256 permissions = data.permissionBits[_account];
        permissions |= _roleBits;
        data.permissionBits[_account] = permissions;

        emit PermissionUpdated(_account, _roleBits);
    }

    /// @dev Revokes the given permissions from an account, without checking the permissions of the caller.
    function _revokeRole(address _account, uint256 _roleBits) internal {
        PermissionStorage.Data storage data = PermissionStorage.data();

        uint256 permissions = data.permissionBits[_account];
        permissions &= ~_roleBits;
        data.permissionBits[_account] = permissions;

        if(permissions == 0 && data.indexOfMember[_account] > 0) {
            uint256 idx = data.indexOfMember[_account];
            uint256 lastIdx = data.roleMemberCount;
            address lastHolder = data.memberAtIndex[lastIdx];

            data.memberAtIndex[idx] = lastHolder;
            data.indexOfMember[lastHolder] = idx;

            delete data.memberAtIndex[lastIdx];
            delete data.indexOfMember[_account];

            data.roleMemberCount--;
        }

        emit PermissionUpdated(_account, permissions);
    }
}
