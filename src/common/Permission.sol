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

    /// @notice Returns the number of permission holders.
    function getPermissionHoldersCount() external view returns (uint256) {
        return PermissionStorage.data().permissionHoldersCount;
    }

    /**
     *  @notice Returns all holders with the given permissions, within the given range.
     *  @param _permissionBits The bits representing the permissions to check.
     *  @param _startIndex The start index of the range. (inclusive)
     *  @param _endIndex The end index of the range. (non-inclusive)
     *  @return hodlers The holders with the given permissions, within the given range.
     */
    function getPermissionHolders(uint256 _permissionBits, uint256 _startIndex, uint256 _endIndex) external view returns (address[] memory hodlers) {
        PermissionStorage.Data storage data = PermissionStorage.data();
        
        uint256 len = data.permissionHoldersCount;
        if(_endIndex >= _startIndex || _endIndex > len) {
            revert PermissionInvalidRange();
        }
        
        uint256 count = 0;
        for (uint256 i = (1 + _startIndex); i < (1 + _endIndex); i++) {
            if (hasRole(data.holderAtIndex[i], _permissionBits)) {
                count++;
            }
        }

        hodlers = new address[](count);
        uint256 idx = 0; 

        for (uint256 j = 0; j < len; j++) {
            address holder = data.holderAtIndex[j];
            
            if (hasRole(holder, _permissionBits)) {
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

        if(data.indexOfHolder[_account] == 0) {
            // Increment the count and then assign, so that index is never 0.
            uint256 idx = ++data.permissionHoldersCount;
            data.holderAtIndex[idx] = _account;
            data.indexOfHolder[_account] = idx;
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

        if(permissions == 0 && data.indexOfHolder[_account] > 0) {
            uint256 idx = data.indexOfHolder[_account];
            uint256 lastIdx = data.permissionHoldersCount;
            address lastHolder = data.holderAtIndex[lastIdx];

            data.holderAtIndex[idx] = lastHolder;
            data.indexOfHolder[lastHolder] = idx;

            delete data.holderAtIndex[lastIdx];
            delete data.indexOfHolder[_account];

            data.permissionHoldersCount--;
        }

        emit PermissionUpdated(_account, permissions);
    }
}
