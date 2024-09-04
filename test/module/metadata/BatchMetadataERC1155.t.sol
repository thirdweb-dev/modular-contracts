// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";
import {Role} from "src/Role.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {BatchMetadataERC1155} from "src/module/token/metadata/BatchMetadataERC1155.sol";
import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {MintableERC1155} from "src/module/token/minting/MintableERC1155.sol";

contract BatchMetadataExt is BatchMetadataERC1155 {}

contract BatchMetadataERC1155Test is Test {

    ERC1155Core public core;

    BatchMetadataExt public moduleImplementation;
    MintableERC1155 public mintableModule;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC1155Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new BatchMetadataExt();
        mintableModule = new MintableERC1155();

        // install module
        vm.prank(owner);
        core.installModule(address(moduleImplementation), "");

        bytes memory encodedInstallParams = abi.encode(owner);
        vm.prank(owner);
        core.installModule(address(mintableModule), encodedInstallParams);

        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `getBatchId`
    //////////////////////////////////////////////////////////////*/

    function test_state_getBatchId() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
        (uint256 batchId, uint256 index) = BatchMetadataExt(address(core)).getBatchId(0);

        assertEq(batchId, 100);
        assertEq(index, 0);
    }

    function test_revert_getBatchId() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        (uint256 batchId, uint256 index) = BatchMetadataExt(address(core)).getBatchId(101);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `getBatchRange`
    //////////////////////////////////////////////////////////////*/

    function test_state_getBatchRange() public {
        vm.startPrank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
        vm.stopPrank();

        (uint256 startTokenId1, uint256 endTokenId1) = BatchMetadataExt(address(core)).getBatchRange(100);
        (uint256 startTokenId2, uint256 endTokenId2) = BatchMetadataExt(address(core)).getBatchRange(200);

        assertEq(startTokenId1, 0);
        assertEq(endTokenId1, 99);
        assertEq(startTokenId2, 100);
        assertEq(endTokenId2, 199);
    }

    function test_revert_getBatchRange() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        vm.prank(owner);
        BatchMetadataExt(address(core)).getBatchRange(101);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setBaseURI`
    //////////////////////////////////////////////////////////////*/

    function test_state_setBaseURI() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // get metadata batches
        BatchMetadataExt.MetadataBatch[] memory batches = BatchMetadataExt(address(core)).getAllMetadataBatches();

        assertEq(batches.length, 1);
        assertEq(batches[0].baseURI, "ipfs://base/");

        vm.prank(owner);
        BatchMetadataExt(address(core)).setBaseURI(100, "ipfs://base2/");

        // get metadata batches
        BatchMetadataExt.MetadataBatch[] memory batches2 = BatchMetadataExt(address(core)).getAllMetadataBatches();

        assertEq(batches2.length, 1);
        assertEq(batches2[0].baseURI, "ipfs://base2/");
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
        assertEq(core.uri(100), "ipfs://base2/0");
        assertEq(core.uri(199), "ipfs://base2/99");
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

    function test_getNextTokenIdToMint() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // get metadata batches
        uint256 nextTokenIdToMint = BatchMetadataExt(address(core)).nextTokenIdToMint();

        assertEq(nextTokenIdToMint, 100);
    }

}
