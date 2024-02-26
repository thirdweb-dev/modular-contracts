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
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Assigns the given permissions to an account, without checking the permissions of the caller.
    function _setupRole(address _account, uint256 _roleBits) internal {
        PermissionStorage.Data storage data = PermissionStorage.data();

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

        emit PermissionUpdated(_account, permissions);
    }
}
