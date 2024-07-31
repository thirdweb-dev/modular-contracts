// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularModule} from "src/ModularModule.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract BatchMetadataExt is BatchMetadataERC721 {}

contract BatchMetadataERC721Test is Test {

    ERC721Core public core;

    BatchMetadataExt public moduleImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new BatchMetadataExt();

        // install module
        vm.prank(owner);
        core.installModule(address(moduleImplementation), "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_uploadMetadata_t() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");

        // upload another batch
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base2/");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");
        assertEq(core.tokenURI(100), "ipfs://base2/100");
        assertEq(core.tokenURI(199), "ipfs://base2/199");
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
