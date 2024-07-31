// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularModule} from "src/ModularModule.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {TransferableERC20} from "src/module/token/transferable/TransferableERC20.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract TransferableExt is TransferableERC20 {}

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
    function _beforeApprove(address from, address to, uint256 amount) internal override {}

}

contract TransferableERC20Test is Test {

    Core public core;

    TransferableExt public moduleImplementation;
    TransferableExt public installedModule;

    address public owner = address(0x1);
    address public actorOne = address(0x2);
    address public actorTwo = address(0x3);
    address public actorThree = address(0x4);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new TransferableExt();

        // install module
        vm.prank(owner);
        core.installModule(address(moduleImplementation), "");

        IModularCore.InstalledModule[] memory installedModules = core.getInstalledModules();
        installedModule = TransferableExt(installedModules[0].implementation);

        // mint tokens
        core.mint(actorOne, 10 ether, "");
        core.mint(actorTwo, 10 ether, "");
        core.mint(actorThree, 10 ether, "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTransferable`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferable() public {
        // transfers enabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(true);

        // transfer tokens
        vm.prank(actorOne);
        core.transfer(actorTwo, 2 ether);

        // read state from core
        assertEq(core.balanceOf(actorOne), 8 ether);
        assertEq(core.balanceOf(actorTwo), 12 ether);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), true);

        // transfers disabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(false);

        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);

        // should revert on transfer tokens
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC20.TransferDisabled.selector);
        core.transfer(actorOne, 1);
    }

    function test_revert_setTransferable() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        TransferableExt(address(core)).setTransferable(true);
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: `setTransferableFor`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferableFor_from() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
        vm.stopPrank();

        // transfer tokens
        vm.prank(actorOne);
        core.transfer(actorTwo, 2 ether);

        // read state from core
        assertEq(core.balanceOf(actorOne), 8 ether);
        assertEq(core.balanceOf(actorTwo), 12 ether);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);

        // should revert when transfer not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC20.TransferDisabled.selector);
        core.transfer(actorThree, 1);
    }

    function test_state_setTransferableFor_to() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorTwo, true);
        vm.stopPrank();

        // transfer tokens
        vm.prank(actorOne);
        core.transfer(actorTwo, 2 ether);

        // read state from core
        assertEq(core.balanceOf(actorOne), 8 ether);
        assertEq(core.balanceOf(actorTwo), 12 ether);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), true);

        // revert when transfers not enabled for
        vm.prank(actorOne);
        vm.expectRevert(TransferableERC20.TransferDisabled.selector);
        core.transfer(actorThree, 1);
    }

    function test_state_setTransferableFor_operator() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
        vm.stopPrank();

        // approve tokens to operator actorOne
        vm.prank(actorTwo);
        core.approve(actorOne, type(uint256).max);

        // transfer tokens
        vm.prank(actorOne);
        core.transferFrom(actorTwo, actorThree, 2 ether);

        // read state from core
        assertEq(core.balanceOf(actorTwo), 8 ether);
        assertEq(core.balanceOf(actorThree), 12 ether);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorThree), false);

        // revert when transfers not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC20.TransferDisabled.selector);
        core.transferFrom(actorTwo, actorThree, 0);
    }

    function test_revert_setTransferableFor() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
    }

    function test_burner_should_not_need_to_approve_to_themselves() public {
        vm.startPrank(actorOne);
        core.burn(actorOne, 1, "");
    }

}
