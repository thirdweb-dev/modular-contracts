// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {DelayedRevealBatchMetadataERC721} from "src/extension/token/metadata/DelayedRevealBatchMetadataERC721.sol";

contract DelayedRevealExt is DelayedRevealBatchMetadataERC721 {
    function tokenIdRangeEnd() external view returns (uint256[] memory) {
        return _delayedRevealBatchMetadataStorage().tokenIdRangeEnd;
    }

    function nextTokenIdRangeStart() external view returns (uint256) {
        return _delayedRevealBatchMetadataStorage().nextTokenIdRangeStart;
    }

    function baseURIOfTokenIdRange(uint256 rangeEnd) external view returns (string memory) {
        return _delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[rangeEnd];
    }

    function encryptedData(uint256 rangeEnd) external view returns (bytes memory) {
        return _delayedRevealBatchMetadataStorage().encryptedData[rangeEnd];
    }
}

contract DelayedRevealBatchMetadataERC721Test is Test {
    ERC721Core public core;

    DelayedRevealExt public extensionImplementation;
    DelayedRevealExt public installedExtension;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC721Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new DelayedRevealExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory installedExtensions = core.getInstalledExtensions();
        installedExtension = DelayedRevealExt(installedExtensions[0].implementation);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_uploadMetadata() public {
        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, "ipfs://base/", "");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");

        // read state from the installed extension
        uint256[] memory rangeEnds = installedExtension.tokenIdRangeEnd();
        assertEq(rangeEnds.length, 1);
        assertEq(rangeEnds[0], 100);
        assertEq(installedExtension.nextTokenIdRangeStart(), 100);
        assertEq(installedExtension.baseURIOfTokenIdRange(100), "ipfs://base/");
        assertEq(installedExtension.encryptedData(100), "");

        // upload another batch
        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, "ipfs://base2/", "");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");
        assertEq(core.tokenURI(100), "ipfs://base2/100");
        assertEq(core.tokenURI(199), "ipfs://base2/199");

        // read state from the installed extension
        rangeEnds = installedExtension.tokenIdRangeEnd();
        assertEq(rangeEnds.length, 2);
        assertEq(rangeEnds[0], 100);
        assertEq(rangeEnds[1], 200);
        assertEq(installedExtension.nextTokenIdRangeStart(), 200);
        assertEq(installedExtension.baseURIOfTokenIdRange(100), "ipfs://base/");
        assertEq(installedExtension.baseURIOfTokenIdRange(200), "ipfs://base2/");
        assertEq(installedExtension.encryptedData(100), "");
        assertEq(installedExtension.encryptedData(200), "");
    }

    function test_state_uploadMetadata_encrypted() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = installedExtension.encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://temp/0");
        assertEq(core.tokenURI(99), "ipfs://temp/0");

        // read state from the installed extension
        uint256[] memory rangeEnds = installedExtension.tokenIdRangeEnd();
        assertEq(rangeEnds.length, 1);
        assertEq(rangeEnds[0], 100);
        assertEq(installedExtension.nextTokenIdRangeStart(), 100);
        assertEq(installedExtension.baseURIOfTokenIdRange(100), tempURI);
        assertEq(installedExtension.encryptedData(100), encryptedData);
    }

    function test_state_reveal() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = installedExtension.encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // reveal
        vm.prank(owner);
        DelayedRevealExt(address(core)).reveal(0, encryptionKey);

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://original/1");
        assertEq(core.tokenURI(99), "ipfs://original/99");

        // read state from the installed extension
        uint256[] memory rangeEnds = installedExtension.tokenIdRangeEnd();
        assertEq(rangeEnds.length, 1);
        assertEq(rangeEnds[0], 100);
        assertEq(installedExtension.nextTokenIdRangeStart(), 100);
        assertEq(installedExtension.baseURIOfTokenIdRange(100), originalURI);
        assertEq(installedExtension.encryptedData(100), "");
    }

    function test_getRevealURI() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = DelayedRevealExt(address(core)).encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // get reveal URI
        string memory revealURI = DelayedRevealExt(address(core)).getRevealURI(0, encryptionKey);
        assertEq(revealURI, originalURI);

        // state unchanged
        assertEq(core.tokenURI(1), "ipfs://temp/0");
        assertEq(core.tokenURI(99), "ipfs://temp/0");
        uint256[] memory rangeEnds = installedExtension.tokenIdRangeEnd();
        assertEq(rangeEnds.length, 1);
        assertEq(rangeEnds[0], 100);
        assertEq(installedExtension.nextTokenIdRangeStart(), 100);
        assertEq(installedExtension.baseURIOfTokenIdRange(100), tempURI);
        assertEq(installedExtension.encryptedData(100), encryptedData);
    }
}
