// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {Module} from "src/Module.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {TransferableERC721} from "src/module/token/transferable/TransferableERC721.sol";

contract TransferableExt is TransferableERC721 {}

contract Core is ERC721Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory modules,
        bytes[] memory moduleInstallData
    ) ERC721Core(name, symbol, contractURI, owner, modules, moduleInstallData) {}

    // disable mint and approve callbacks for these tests
    function _beforeMint(address to, uint256 startTokenId, uint256 quantity, bytes calldata data) internal override {}
    function _beforeApproveForAll(address from, address to, bool approved) internal override {}

}

contract TransferableERC721Test is Test {

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

        ICore.InstalledModule[] memory installedModules = core.getInstalledModules();
        installedModule = TransferableExt(installedModules[0].implementation);

        // mint tokens
        core.mint(actorOne, 1, ""); // tokenId 0
        core.mint(actorTwo, 1, ""); // tokenId 1
        core.mint(actorThree, 1, ""); // tokenId 2
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
        core.transferFrom(actorOne, actorTwo, 0);

        // read state from core
        assertEq(core.ownerOf(0), actorTwo);
        assertEq(core.ownerOf(1), actorTwo);
        assertEq(core.balanceOf(actorOne), 0);
        assertEq(core.balanceOf(actorTwo), 2);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), true);

        // transfers disabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(false);

        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);

        // should revert on transfer tokens
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC721.TransferDisabled.selector);
        core.transferFrom(actorTwo, actorOne, 0);
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
        core.transferFrom(actorOne, actorTwo, 0);

        // read state from core
        assertEq(core.ownerOf(0), actorTwo);
        assertEq(core.ownerOf(1), actorTwo);
        assertEq(core.balanceOf(actorOne), 0);
        assertEq(core.balanceOf(actorTwo), 2);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);

        // revert when transfers not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC721.TransferDisabled.selector);
        core.transferFrom(actorTwo, actorThree, 0);
    }

    function test_state_setTransferableFor_to() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorTwo, true);
        vm.stopPrank();

        // transfer tokens
        vm.prank(actorOne);
        core.transferFrom(actorOne, actorTwo, 0);

        // read state from core
        assertEq(core.ownerOf(0), actorTwo);
        assertEq(core.ownerOf(1), actorTwo);
        assertEq(core.balanceOf(actorOne), 0);
        assertEq(core.balanceOf(actorTwo), 2);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), true);

        // revert when transfers not enabled for
        vm.prank(actorOne);
        vm.expectRevert(TransferableERC721.TransferDisabled.selector);
        core.transferFrom(actorOne, actorThree, 0);
    }

    function test_state_setTransferableFor_operator() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
        vm.stopPrank();

        // approve tokens to operator actorOne
        vm.prank(actorTwo);
        core.setApprovalForAll(actorOne, true);

        // transfer tokens
        vm.prank(actorOne);
        core.transferFrom(actorTwo, actorThree, 1);

        // read state from core
        assertEq(core.ownerOf(1), actorThree);
        assertEq(core.ownerOf(2), actorThree);
        assertEq(core.balanceOf(actorTwo), 0);
        assertEq(core.balanceOf(actorThree), 2);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorThree), false);

        // revert when transfers not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC721.TransferDisabled.selector);
        core.transferFrom(actorTwo, actorThree, 0);
    }

    function test_revert_setTransferableFor() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
    }

}
