// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularModule} from "src/ModularModule.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {SimpleMetadataERC1155} from "src/module/token/metadata/SimpleMetadataERC1155.sol";
import {SimpleMetadataERC721, SimpleMetadataStorage} from "src/module/token/metadata/SimpleMetadataERC721.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract SimpleMetadataExt is SimpleMetadataERC1155 {}

contract SimpleMetadataERC1155Test is Test {

    ERC1155Core public core;

    SimpleMetadataExt public moduleImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC1155Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new SimpleMetadataExt();

        // install module
        vm.prank(owner);
        core.installModule(address(moduleImplementation), "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTokenURI`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTokenURI() public {
        vm.prank(owner);
        SimpleMetadataExt(address(core)).setTokenURI(1, "ipfs://base/1");

        vm.prank(owner);
        SimpleMetadataExt(address(core)).setTokenURI(2, "ipfs://base/2");

        // read state from core
        assertEq(core.uri(1), "ipfs://base/1");
        assertEq(core.uri(2), "ipfs://base/2");

        vm.expectRevert(abi.encodeWithSelector(SimpleMetadataERC721.MetadataNoMetadataForTokenId.selector));
        core.uri(3);
    }

    function test_revert_setTokenURI() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        SimpleMetadataExt(address(core)).setTokenURI(1, "ipfs://base/");
    }

    function test_audit_does_not_set_name_and_symbol() public {
        assertEq(core.name(), "test");
        assertEq(core.symbol(), "TEST");
    }

}
