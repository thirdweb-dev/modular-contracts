// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Permission } from "src/common/Permission.sol";

contract PermissionExample is Permission {

    constructor(address _admin) {
        _setupRole(_admin, ADMIN_ROLE_BITS);
    }
}

contract PermissionTest is Test {

    PermissionExample permission;
    address public admin = address(0x123);

    uint256 public permissionBitsOne = 2 ** 2;
    uint256 public permissionBitsTwo = 2 ** 3;
    uint256 public permissionBitsThree = 2 ** 4;

    mapping(address => bool) public setRole;

    function setUp() public {
        permission = new PermissionExample(admin);
    }

    function test_roles() public {

        uint256 count = 100;

        for (uint256 i = 1; i <= count; i++) {
            address account = address(uint160(i));

            vm.startPrank(admin);

            permission.grantRole(account, permissionBitsOne);
            permission.grantRole(account, permissionBitsTwo);
            permission.grantRole(account, permissionBitsThree);

            vm.stopPrank();

            setRole[account] = true;

            assert(permission.hasRole(account, permissionBitsOne | permissionBitsTwo | permissionBitsThree));
        }

        address[] memory accounts = permission.getRoleMembers(permissionBitsOne | permissionBitsTwo | permissionBitsThree, 0, permission.getRoleMemberCount());
        assertEq(accounts.length, 100);

        for(uint256 i = 0; i < accounts.length; i++) {
            assert(setRole[accounts[i]]);
        }

        for (uint256 i = 25; i <= 74; i++) {
            address account = address(uint160(i));

            vm.startPrank(admin);

            permission.revokeRole(account, permissionBitsOne);
            permission.revokeRole(account, permissionBitsTwo);
            permission.revokeRole(account, permissionBitsThree);

            vm.stopPrank();

            setRole[account] = false;

            assert(!permission.hasRole(account, permissionBitsOne | permissionBitsTwo | permissionBitsThree));
        }

        address[] memory accountsAfter = permission.getRoleMembers(permissionBitsOne | permissionBitsTwo | permissionBitsThree, 0, permission.getRoleMemberCount());
        assertEq(accountsAfter.length, 50);
    }
}