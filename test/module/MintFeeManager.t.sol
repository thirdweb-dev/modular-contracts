// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Role} from "src/Role.sol";

import {MintFeeManagerCore} from "src/core/MintFeeManagerCore.sol";
import {MintFeeManagerModule} from "src/module/MintFeeManagerModule.sol";

contract MintFeeManagerTest is Test {

    MintFeeManagerCore public mintFeeManagerCoreImplementation;
    MintFeeManagerModule public mintFeeManagerModuleImplementation;
    address payable public mintFeeManagerProxy;

    address public owner = address(0x123);
    address public platformFeeRecipient = address(0x456);
    uint256 public defaultMintFee = 100;
    address public unauthorizedActor = address(0x3);

    address public contract1 = address(0x1);
    address public contract2 = address(0x2);

    event MintFeeUpdated(address indexed contractAddress, uint256 mintFee);
    event DefaultMintFeeUpdated(uint256 mintFee);

    function setUp() public {
        // Deploy the contract
        mintFeeManagerCoreImplementation = new MintFeeManagerCore();
        mintFeeManagerModuleImplementation = new MintFeeManagerModule();
        mintFeeManagerProxy = payable(LibClone.clone(address(mintFeeManagerCoreImplementation)));

        MintFeeManagerCore(mintFeeManagerProxy).initialize(owner);

        bytes memory initializeData =
            mintFeeManagerModuleImplementation.encodeBytesOnInstall(platformFeeRecipient, defaultMintFee);
        vm.prank(owner);
        MintFeeManagerCore(mintFeeManagerProxy).installModule(
            address(mintFeeManagerModuleImplementation), initializeData
        );

        vm.prank(owner);
        MintFeeManagerCore(mintFeeManagerProxy).grantRoles(owner, Role._MANAGER_ROLE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setPlatformFeeRecipient`
    //////////////////////////////////////////////////////////////*/

    function test_state_setPlatformFeeRecipient() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerProxy).setPlatformFeeRecipient(address(0x456));

        assertEq(MintFeeManagerModule(mintFeeManagerProxy).getPlatformFeeRecipient(), address(0x456));
    }

    function test_revert_setPlatformFeeRecipient_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerProxy).setPlatformFeeRecipient(address(0x456));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `updateMintFee`
    //////////////////////////////////////////////////////////////*/

    function test_state_updateMintFee() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit MintFeeUpdated(contract1, 500);
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract1, 500);

        vm.expectEmit(true, true, true, true);
        emit MintFeeUpdated(contract2, type(uint256).max);
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract2, type(uint256).max);
        vm.stopPrank();

        assertEq(MintFeeManagerModule(mintFeeManagerProxy).getMintFees(contract1), 500);
        assertEq(MintFeeManagerModule(mintFeeManagerProxy).getMintFees(contract2), type(uint256).max);
    }

    function test_revert_updateMintFee_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract1, 100);
    }

    function test_revert_updateMintFee_invalidMintFee() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MintFeeManagerModule.MintFeeExceedsMaxBps.selector));
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract1, 10_001);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setDefaultMintFee`
    //////////////////////////////////////////////////////////////*/

    function test_state_setDefaultMintFee() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DefaultMintFeeUpdated(500);
        MintFeeManagerModule(mintFeeManagerProxy).setDefaultMintFee(500);

        assertEq(MintFeeManagerModule(mintFeeManagerProxy).getDefaultMintFee(), 500);
    }

    function test_revert_setDefaultMintFee_unauthorizedCaller() public {
        vm.prank(unauthorizedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintFeeManagerModule(mintFeeManagerProxy).setDefaultMintFee(100);
    }

    function test_revert_setDefaultMintFee_invalidMintFee() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(MintFeeManagerModule.MintFeeExceedsMaxBps.selector));
        MintFeeManagerModule(mintFeeManagerProxy).setDefaultMintFee(10_001);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `getPlatformFeeAndRecipient`
    //////////////////////////////////////////////////////////////*/

    function test_state_getPlatformFeeAndRecipient() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract1, 500);

        vm.prank(contract1);
        (uint256 mintFee, address _platformFeeRecipient) =
            MintFeeManagerModule(mintFeeManagerProxy).getPlatformFeeAndRecipient(100);

        assertEq(mintFee, 5);
        assertEq(_platformFeeRecipient, platformFeeRecipient);
    }

    function test_state_getPlatformFeeAndRecipient_defaultMintFee() public {
        vm.prank(contract1);
        (uint256 mintFee, address _platformFeeRecipient) =
            MintFeeManagerModule(mintFeeManagerProxy).getPlatformFeeAndRecipient(100);

        assertEq(mintFee, 1);
        assertEq(_platformFeeRecipient, platformFeeRecipient);
    }

    function test_state_getPlatformFeeAndRecipient_zeroMintFee() public {
        vm.prank(owner);
        MintFeeManagerModule(mintFeeManagerProxy).updateMintFee(contract1, type(uint256).max);

        vm.prank(contract1);
        (uint256 mintFee, address _platformFeeRecipient) =
            MintFeeManagerModule(mintFeeManagerProxy).getPlatformFeeAndRecipient(100);

        assertEq(mintFee, 0);
        assertEq(_platformFeeRecipient, platformFeeRecipient);
    }

}
