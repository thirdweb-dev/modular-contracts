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
import {SuperChainInterop} from "src/module/token/crosschain/SuperChainInterop.sol";

contract Core is ERC20Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory modules,
        bytes[] memory moduleInstallData
    ) payable ERC20Core(name, symbol, contractURI, owner, modules, moduleInstallData) {}

    // disable mint callbacks for these tests
    function _beforeMint(address to, uint256 amount, bytes calldata data) internal override {}

}

contract MintableERC20Test is Test {

    Core public core;

    SuperChainInterop public superchainInterop;

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
        superchainInterop = new SuperChainInterop();

        // install module
        bytes memory encodedInstallParams = superchainInterop.encodeBytesOnInstall(superchainBridge);
        vm.prank(owner);
        core.installModule(address(superchainInterop), encodedInstallParams);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: get / set SuperChainBridge
    //////////////////////////////////////////////////////////////*/

    function test_state_setSuperChainBridge() public {
        vm.prank(owner);
        SuperChainInterop(address(core)).setSuperChainBridge(address(0x123));

        assertEq(SuperChainInterop(address(core)).getSuperChainBridge(), address(0x123));
    }

    function test_revert_setSuperChainBridge_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        SuperChainInterop(address(core)).setSuperChainBridge(address(0x123));
    }

    function test_getSuperChainBridge_state() public {
        assertEq(SuperChainInterop(address(core)).getSuperChainBridge(), superchainBridge);
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
        SuperChainInterop(address(core)).crosschainMint(actor1, 10 ether);

        assertEq(core.balanceOf(actor1), 10 ether);
    }

    function test_crosschainMint_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(SuperChainInterop.SuperChainInteropNotSuperChainBridge.selector));
        SuperChainInterop(address(core)).crosschainMint(actor1, 10 ether);
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
        SuperChainInterop(address(core)).crosschainBurn(actor1, 10 ether);

        assertEq(core.balanceOf(actor1), 0);
    }

    function test_crosschainBurn_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(SuperChainInterop.SuperChainInteropNotSuperChainBridge.selector));
        SuperChainInterop(address(core)).crosschainBurn(actor1, 10 ether);
    }

}
