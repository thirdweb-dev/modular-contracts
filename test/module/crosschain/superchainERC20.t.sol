// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

// Target contract

import {Module} from "src/Module.sol";

import {Role} from "src/Role.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {SuperChainERC20} from "src/module/token/crosschain/SuperChainERC20.sol";

contract Core is ERC20Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory modules,
        bytes[] memory moduleInstallData
    ) payable ERC20Core(name, symbol, contractURI, owner, modules, moduleInstallData) {}

    // disable mint and approve callbacks for these tests
    function _beforeMint(address to, uint256 amount, bytes calldata data) internal override {}

}

contract MintableERC20Test is Test {

    Core public core;

    SuperChainERC20 public superchainERC20;

    uint256 ownerPrivateKey = 1;
    address public owner;
    address public superchainBridge = address(0x123);
    address public actor1 = address(0x111);
    address public unpermissionedActor = address(0x222);

    event CrosschainMinted(address indexed _to, uint256 _amount);
    event CrosschainBurnt(address indexed _from, uint256 _amount);

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);

        address[] memory modules;
        bytes[] memory moduleData;

        core = new Core("test", "TEST", "", owner, modules, moduleData);
        superchainERC20 = new SuperChainERC20();

        // install module
        bytes memory encodedInstallParams = superchainERC20.encodeBytesOnInstall(superchainBridge);
        vm.prank(owner);
        core.installModule(address(superchainERC20), encodedInstallParams);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: get / set SuperChainBridge
    //////////////////////////////////////////////////////////////*/

    function test_state_setSuperChainBridge() public {
        vm.prank(owner);
        SuperChainERC20(address(core)).setSuperChainBridge(address(0x123));

        assertEq(SuperChainERC20(address(core)).getSuperChainBridge(), address(0x123));
    }

    function test_revert_setSuperChainBridge_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        SuperChainERC20(address(core)).setSuperChainBridge(address(0x123));
    }

    function test_getSuperChainBridge_state() public {
        assertEq(SuperChainERC20(address(core)).getSuperChainBridge(), superchainBridge);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: CrossChainMint
    //////////////////////////////////////////////////////////////*/

    function test_crosschainMint_state() public {
        uint256 balanceBefore = core.balanceOf(actor1);
        assertEq(balanceBefore, 0);

        vm.prank(superchainBridge);
        vm.expectEmit(true, true, true, true);
        emit CrosschainMinted(actor1, 10 ether);
        SuperChainERC20(address(core)).crosschainMint(actor1, 10 ether);

        assertEq(core.balanceOf(actor1), 10 ether);
    }

    function test_crosschainMint_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(SuperChainERC20.SuperChainERC20NotSuperChainBridge.selector));
        SuperChainERC20(address(core)).crosschainMint(actor1, 10 ether);
    }


    /*//////////////////////////////////////////////////////////////
                        Tests: CrossChainBurn
    //////////////////////////////////////////////////////////////*/

    function test_crosschainBurn_state() public {
        core.mint(actor1, 10 ether, "");

        uint256 balanceBefore = core.balanceOf(actor1);
        assertEq(balanceBefore, 10 ether);

        vm.prank(superchainBridge);
        vm.expectEmit(true, true, true, true);
        emit CrosschainBurnt(actor1, 10 ether);
        SuperChainERC20(address(core)).crosschainBurn(actor1, 10 ether);

        assertEq(core.balanceOf(actor1), 0);
    }

    function test_crosschainBurn_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(SuperChainERC20.SuperChainERC20NotSuperChainBridge.selector));
        SuperChainERC20(address(core)).crosschainBurn(actor1, 10 ether);
    }

}
