// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {TransferableERC1155} from "src/extension/token/transferable/TransferableERC1155.sol";

contract TransferableExt is TransferableERC1155 {}

contract Core is ERC1155Core {
    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory extensions,
        bytes[] memory extensionInstallData
    ) ERC1155Core(name, symbol, contractURI, owner, extensions, extensionInstallData) {}

    // disable mint and approve callbacks for these tests
    function _beforeMint(address to, uint256 tokenId, uint256 value, bytes memory data) internal override {}
    function _beforeApproveForAll(address from, address to, bool approved) internal override {}
}

contract TransferableERC1155Test is Test {
    Core public core;

    TransferableExt public extensionImplementation;
    TransferableExt public installedExtension;

    address public owner = address(0x1);
    address public actorOne = address(0x2);
    address public actorTwo = address(0x3);
    address public actorThree = address(0x4);

    function setUp() public {
        address[] memory extensions;
        bytes[] memory extensionData;

        core = new Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new TransferableExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory installedExtensions = core.getInstalledExtensions();
        installedExtension = TransferableExt(installedExtensions[0].implementation);

        // mint tokens
        // tokenId 0
        core.mint(actorOne, 0, 10, "");
        core.mint(actorTwo, 0, 10, "");
        core.mint(actorThree, 0, 10, "");
        // tokenId 1
        core.mint(actorOne, 1, 10, "");
        core.mint(actorTwo, 1, 10, "");
        core.mint(actorThree, 1, 10, "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTransferable`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferable_transferSingleToken() public {
        // transfers enabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(true);

        // transfer tokens
        vm.prank(actorOne);
        core.safeTransferFrom(actorOne, actorTwo, 0, 2, "");

        // read state from core
        assertEq(core.balanceOf(actorOne, 0), 8);
        assertEq(core.balanceOf(actorTwo, 0), 12);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), true);

        // transfers disabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(false);

        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);

        // should revert on transfer tokens
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC1155.TransferDisabled.selector);
        core.safeTransferFrom(actorTwo, actorOne, 0, 2, "");
    }

    function test_state_setTransferable_transferBatch() public {
        // transfers enabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(true);

        // batch
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory values = new uint256[](2);

        tokenIds[0] = 0;
        tokenIds[1] = 1;
        values[0] = 2;
        values[1] = 3;

        // transfer tokens
        vm.prank(actorOne);
        core.safeBatchTransferFrom(actorOne, actorTwo, tokenIds, values, "");

        // // read state from core
        assertEq(core.balanceOf(actorOne, 0), 8);
        assertEq(core.balanceOf(actorTwo, 0), 12);
        assertEq(core.balanceOf(actorOne, 1), 7);
        assertEq(core.balanceOf(actorTwo, 1), 13);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), true);

        // transfers disabled globally
        vm.prank(owner);
        TransferableExt(address(core)).setTransferable(false);

        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);

        // should revert on transfer tokens
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC1155.TransferDisabled.selector);
        core.safeBatchTransferFrom(actorTwo, actorOne, tokenIds, values, "");
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
        core.safeTransferFrom(actorOne, actorTwo, 0, 2, "");

        // read state from core
        assertEq(core.balanceOf(actorOne, 0), 8);
        assertEq(core.balanceOf(actorTwo, 0), 12);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);

        // revert when transfers not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC1155.TransferDisabled.selector);
        core.safeTransferFrom(actorTwo, actorThree, 0, 2, "");
    }

    function test_state_setTransferableFor_to() public {
        // transfers disabled globally
        vm.startPrank(owner);
        TransferableExt(address(core)).setTransferable(false);
        TransferableExt(address(core)).setTransferableFor(actorTwo, true);
        vm.stopPrank();

        // transfer tokens
        vm.prank(actorOne);
        core.safeTransferFrom(actorOne, actorTwo, 0, 2, "");

        // read state from core
        assertEq(core.balanceOf(actorOne, 0), 8);
        assertEq(core.balanceOf(actorTwo, 0), 12);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), true);

        // revert when transfers not enabled for
        vm.prank(actorOne);
        vm.expectRevert(TransferableERC1155.TransferDisabled.selector);
        core.safeTransferFrom(actorOne, actorThree, 0, 2, "");
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
        core.safeTransferFrom(actorTwo, actorThree, 0, 2, "");

        // read state from core
        assertEq(core.balanceOf(actorTwo, 0), 8);
        assertEq(core.balanceOf(actorThree, 0), 12);
        assertEq(TransferableExt(address(core)).isTransferEnabled(), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorOne), true);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorTwo), false);
        assertEq(TransferableExt(address(core)).isTransferEnabledFor(actorThree), false);

        // revert when transfers not enabled for
        vm.prank(actorTwo);
        vm.expectRevert(TransferableERC1155.TransferDisabled.selector);
        core.safeTransferFrom(actorTwo, actorThree, 0, 1, "");
    }

    function test_revert_setTransferableFor() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        TransferableExt(address(core)).setTransferableFor(actorOne, true);
    }
}
