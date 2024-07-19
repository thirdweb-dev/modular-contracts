// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {BatchMetadataERC1155} from "src/extension/token/metadata/BatchMetadataERC1155.sol";
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract BatchMetadataExt is BatchMetadataERC1155 {}

contract BatchMetadataERC1155Test is Test {

    ERC1155Core public core;

    BatchMetadataExt public extensionImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC1155Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new BatchMetadataExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_uploadMetadata() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // read state from core
        assertEq(core.uri(1), "ipfs://base/1");
        assertEq(core.uri(99), "ipfs://base/99");

        // upload another batch
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base2/");

        // read state from core
        assertEq(core.uri(1), "ipfs://base/1");
        assertEq(core.uri(99), "ipfs://base/99");
        assertEq(core.uri(100), "ipfs://base2/100");
        assertEq(core.uri(199), "ipfs://base2/199");
    }

    function test_revert_uploadMetadata() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
    }

    function test_getAllMetadataBatches() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // get metadata batches
        BatchMetadataExt.MetadataBatch[] memory batches = BatchMetadataExt(address(core)).getAllMetadataBatches();

        assertEq(batches.length, 1);
        assertEq(batches[0].startTokenIdInclusive, 0);
        assertEq(batches[0].endTokenIdInclusive, 99);
        assertEq(batches[0].baseURI, "ipfs://base/");
    }

}
