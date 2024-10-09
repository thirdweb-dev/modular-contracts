// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "lib/forge-std/src/console.sol";

// Target contracts
import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";
import {Role} from "src/Role.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {MintableERC721} from "src/module/token/minting/MintableERC721.sol";

contract BatchMetadataExt is BatchMetadataERC721 {

    // Expose internal functions for testing
    function exposed_getBaseURI(uint256 _tokenId) external view returns (string memory baseUri, uint256 indexInBatch) {
        return _getBaseURI(_tokenId);
    }

}

contract BatchMetadataERC721Test is Test {

    ERC721Core public core;

    BatchMetadataExt public batchMetadataModule;
    MintableERC721 public mintableModule;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    event BatchMetadataUpdate(uint256 startTokenIdIncluside, uint256 endTokenIdInclusive, string baseURI);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        batchMetadataModule = new BatchMetadataExt();
        mintableModule = new MintableERC721();

        // Install modules
        vm.prank(owner);
        core.installModule(address(batchMetadataModule), "");

        bytes memory encodedInstallParams = abi.encode(owner);
        vm.prank(owner);
        core.installModule(address(mintableModule), encodedInstallParams);

        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `updateMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_updateMetadata() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(0, 0, "ipfs://base/");
        core.mint(owner, 1, "ipfs://base/", "");

        assertEq(core.tokenURI(0), "ipfs://base/0");

        // Test case: user mints 10 tokens with no baseURI
        //            user mints another 10 tokens with baseURI
        // Expected: tokenURI for tokenId 15 should be ipfs://base2/4
        vm.startPrank(owner);
        core.mint(owner, 10, "", "");

        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(11, 20, "ipfs://base2/");
        core.mint(owner, 10, "ipfs://base2/", "");
        vm.stopPrank();

        assertEq(core.tokenURI(15), "ipfs://base2/4");
    }

    function test_revert_updateMetadata() public {
        vm.prank(owner);
        core.mint(owner, 1, "", "");

        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        core.tokenURI(0);

        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.prank(owner);
        vm.expectRevert(BatchMetadataERC721.BatchMetadataMetadataAlreadySet.selector);
        core.mint(owner, 1, "ipfs://base/fail", "");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_uploadMetadata() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");

        // Upload another batch
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base2/");

        // Read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");
        // fails here
        assertEq(core.tokenURI(100), "ipfs://base2/0");
        assertEq(core.tokenURI(199), "ipfs://base2/99");
    }

    function test_revert_uploadMetadata() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
    }

    function test_revert_uploadMetadata_zeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(BatchMetadataERC721.BatchMetadataZeroAmount.selector);
        BatchMetadataExt(address(core)).uploadMetadata(0, "ipfs://base/");
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: `getAllMetadataBatches`
    //////////////////////////////////////////////////////////////*/

    function test_getAllMetadataBatches() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Get metadata batches
        BatchMetadataExt.MetadataBatch[] memory batches = BatchMetadataExt(address(core)).getAllMetadataBatches();

        assertEq(batches.length, 1);
        assertEq(batches[0].startTokenIdInclusive, 0);
        assertEq(batches[0].endTokenIdInclusive, 99);
        assertEq(batches[0].baseURI, "ipfs://base/");
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `nextTokenIdToMint`
    //////////////////////////////////////////////////////////////*/

    function test_nextTokenIdToMint() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Get nextTokenIdToMint
        uint256 nextTokenIdToMint = BatchMetadataExt(address(core)).nextTokenIdToMint();

        assertEq(nextTokenIdToMint, 100);
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: `getMetadataBatch`
    //////////////////////////////////////////////////////////////*/

    function test_state_getMetadataBatch() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Get metadata batch at index 0
        BatchMetadataExt.MetadataBatch memory batch = BatchMetadataExt(address(core)).getMetadataBatch(0);

        assertEq(batch.startTokenIdInclusive, 0);
        assertEq(batch.endTokenIdInclusive, 99);
        assertEq(batch.baseURI, "ipfs://base/");
    }

    function test_revert_getMetadataBatch_invalidIndex() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Try to get batch at invalid index
        vm.expectRevert();
        BatchMetadataExt(address(core)).getMetadataBatch(1);
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: `getBatchIndex`
    //////////////////////////////////////////////////////////////*/

    function test_state_getBatchIndex() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Check batch index for token IDs within the batch
        uint256 batchIndex = BatchMetadataExt(address(core)).getBatchIndex(50);
        assertEq(batchIndex, 0);

        // Upload another batch
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base2/");

        // Check batch index for token IDs in the second batch
        batchIndex = BatchMetadataExt(address(core)).getBatchIndex(150);
        assertEq(batchIndex, 1);
    }

    function test_revert_getBatchIndex_noMetadata() public {
        // No metadata uploaded yet
        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        BatchMetadataExt(address(core)).getBatchIndex(0);

        // Upload metadata
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Test tokenId beyond range
        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        BatchMetadataExt(address(core)).getBatchIndex(200);
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: `setBaseURI`
    //////////////////////////////////////////////////////////////*/

    function test_state_setBaseURI() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Set new baseURI for batch 0
        vm.prank(owner);
        BatchMetadataExt(address(core)).setBaseURI(0, "ipfs://newbase/");

        // Check that the baseURI has been updated
        BatchMetadataExt.MetadataBatch memory batch = BatchMetadataExt(address(core)).getMetadataBatch(0);
        assertEq(batch.baseURI, "ipfs://newbase/");

        // Check that tokenURI returns the updated baseURI
        assertEq(core.tokenURI(0), "ipfs://newbase/0");
    }

    function test_event_setBaseURI() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Expect BatchMetadataUpdate event
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(0, 99, "ipfs://newbase/");

        BatchMetadataExt(address(core)).setBaseURI(0, "ipfs://newbase/");
    }

    function test_revert_setBaseURI_unauthorized() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Try to set baseURI as unpermissionedActor
        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // Unauthorized()
        BatchMetadataExt(address(core)).setBaseURI(0, "ipfs://hack/");
    }

    function test_revert_setBaseURI_invalidIndex() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.prank(owner);
        vm.expectRevert();
        BatchMetadataExt(address(core)).setBaseURI(1, "ipfs://newbase/");
    }

    /*///////////////////////////////////////////////////////////////
                    Unit tests: TokenURI edge cases
    //////////////////////////////////////////////////////////////*/

    function test_state_tokenURI_multipleBatches() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(50, "ipfs://base2/");

        // Mint tokens
        vm.prank(owner);
        core.mint(owner, 150, "", "");

        // Check tokenURI for tokens in first batch
        assertEq(core.tokenURI(0), "ipfs://base/0");
        assertEq(core.tokenURI(99), "ipfs://base/99");

        // Check tokenURI for tokens in second batch
        assertEq(core.tokenURI(100), "ipfs://base2/0");
        assertEq(core.tokenURI(149), "ipfs://base2/49");

        // tokenURI for token beyond batches should revert
        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        core.tokenURI(150);
    }

    function test_revert_tokenURI_noMetadata() public {
        vm.prank(owner);
        core.mint(owner, 1, "", "");

        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        core.tokenURI(0);
    }

    function test_revert_tokenURI_noMetadataBeyondUploaded() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        // Mint 200 tokens
        vm.prank(owner);
        core.mint(owner, 200, "", "");

        // tokenURI for tokenId 150 should revert
        vm.expectRevert(BatchMetadataERC721.BatchMetadataNoMetadataForTokenId.selector);
        core.tokenURI(150);
    }

    /*///////////////////////////////////////////////////////////////
                Unit tests: Unauthorized access checks
    //////////////////////////////////////////////////////////////*/

    function test_revert_uploadMetadata_unauthorized() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // Unauthorized()
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");
    }

    function test_revert_setBaseURI_unauthorizedActor() public {
        vm.prank(owner);
        BatchMetadataExt(address(core)).uploadMetadata(100, "ipfs://base/");

        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // Unauthorized()
        BatchMetadataExt(address(core)).setBaseURI(0, "ipfs://newbase/");
    }

}
