// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Role} from "src/Role.sol";

import {MintFeeManagerCore} from "src/core/MintFeeManagerCore.sol";
import {MintFeeManagerModule} from "src/module/MintFeeManagerModule.sol";

contract MintFeeManagerTest is Test {

    address public mintFeeManagerCore;
    MintFeeManagerModule public mintFeeManagerModule;

    address public owner = address(0x123);
    address public feeRecipient = address(0x456);
    uint256 public defaultMintFee = 100;
    address public unauthorizedActor = address(0x3);

    address public contract1 = address(0x1);
    address public contract2 = address(0x2);

    event MintFeeUpdated(address indexed contractAddress, uint256 mintFee);
    event DefaultMintFeeUpdated(uint256 mintFee);

    function setUp() public {
        // Deploy the contract
        address[] memory modules;
        bytes[] memory moduleData;
        mintFeeManagerCore = address(new MintFeeManagerCore(owner, modules, moduleData));
        mintFeeManagerModule = new MintFeeManagerModule();

        bytes memory initializeData = mintFeeManagerModule.encodeBytesOnInstall(feeRecipient, defaultMintFee);
        vm.prank(owner);
        MintFeeManagerCore(payable(mintFeeManagerCore)).installModule(address(mintFeeManagerModule), initializeData);

        vm.prank(owner);
        MintFeeManagerCore(payable(mintFeeManagerCore)).grantRoles(owner, Role._MANAGER_ROLE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setfeeRecipient`
    //////////////////////////////////////////////////////////////*/

    function test_state_setfeeRecipient() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerCore).setfeeRecipient(address(0x456));

        assertEq(MintFeeManagerModule(mintFeeManagerCore).getfeeRecipient(), address(0x456));
    }

    function test_revert_setfeeRecipient_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerCore).setfeeRecipient(address(0x456));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `updateMintFee`
    //////////////////////////////////////////////////////////////*/

    function test_state_updateMintFee() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit MintFeeUpdated(contract1, 500);
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract1, 500);

        vm.expectEmit(true, true, true, true);
        emit MintFeeUpdated(contract2, type(uint256).max);
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract2, type(uint256).max);
        vm.stopPrank();

        assertEq(MintFeeManagerModule(mintFeeManagerCore).getMintFees(contract1), 500);
        assertEq(MintFeeManagerModule(mintFeeManagerCore).getMintFees(contract2), type(uint256).max);
    }

    function test_revert_updateMintFee_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract1, 100);
    }

    function test_revert_updateMintFee_invalidMintFee() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MintFeeManagerModule.MintFeeExceedsMaxBps.selector));
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract1, 10_001);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setDefaultMintFee`
    //////////////////////////////////////////////////////////////*/

    function test_state_setDefaultMintFee() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DefaultMintFeeUpdated(500);
        MintFeeManagerModule(mintFeeManagerCore).setDefaultMintFee(500);

        assertEq(MintFeeManagerModule(mintFeeManagerCore).getDefaultMintFee(), 500);
    }

    function test_revert_setDefaultMintFee_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerCore).setDefaultMintFee(100);
    }

    function test_revert_setDefaultMintFee_invalidMintFee() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MintFeeManagerModule.MintFeeExceedsMaxBps.selector));
        MintFeeManagerModule(mintFeeManagerCore).setDefaultMintFee(10_001);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `calculatePlatformFeeAndRecipient`
    //////////////////////////////////////////////////////////////*/

    function test_state_calculatePlatformFeeAndRecipient() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract1, 500);

        vm.prank(contract1);
        (uint256 mintFee, address _feeRecipient) =
            MintFeeManagerModule(mintFeeManagerCore).calculatePlatformFeeAndRecipient(100);

        assertEq(mintFee, 5);
        assertEq(_feeRecipient, feeRecipient);
    }

    function test_state_calculatePlatformFeeAndRecipient_defaultMintFee() public {
        vm.prank(contract1);
        (uint256 mintFee, address _feeRecipient) =
            MintFeeManagerModule(mintFeeManagerCore).calculatePlatformFeeAndRecipient(100);

        assertEq(mintFee, 1);
        assertEq(_feeRecipient, feeRecipient);
    }

    function test_state_calculatePlatformFeeAndRecipient_zeroMintFee() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerCore).updateMintFee(contract1, type(uint256).max);

        vm.prank(contract1);
        (uint256 mintFee, address _feeRecipient) =
            MintFeeManagerModule(mintFeeManagerCore).calculatePlatformFeeAndRecipient(100);

        assertEq(mintFee, 0);
        assertEq(_feeRecipient, feeRecipient);
    }

}
