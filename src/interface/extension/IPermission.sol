// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

interface IPermission {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an unauthorized caller attempts a restricted action.
    error PermissionUnauthorized(address caller, uint256 permissionBits);

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an account's permissions are updated.
    event PermissionUpdated(address indexed account, uint256 permissionBits);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns whether an account has the given permissions.
     *  @param account The account to check.
     *  @param roleBits The bits representing the permissions to check.
     *  @return hasPermissions Whether the account has the given permissions.
     */
    function hasRole(address account, uint256 roleBits) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Grants the given permissions to an account.
     *  @param account The account to grant permissions to.
     *  @param roleBits The bits representing the permissions to grant.
     */
    function grantRole(address account, uint256 roleBits) external;

    /**
     *  @notice Revokes the given permissions from an account.
     *  @param account The account to revoke permissions from.
     *  @param roleBits The bits representing the permissions to revoke.
     */
    function revokeRole(address account, uint256 roleBits) external;
}
