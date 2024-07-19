// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {SimpleMetadataERC1155} from "src/extension/token/metadata/SimpleMetadataERC1155.sol";
import {SimpleMetadataERC721, SimpleMetadataStorage} from "src/extension/token/metadata/SimpleMetadataERC721.sol";
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract SimpleMetadataExt is SimpleMetadataERC1155 {}

contract SimpleMetadataERC1155Test is Test {

    ERC1155Core public core;

    SimpleMetadataExt public extensionImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC1155Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new SimpleMetadataExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");
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
