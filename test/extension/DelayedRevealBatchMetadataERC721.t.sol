// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "@solady/utils/ERC1967FactoryConstants.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCoreUpgradeable} from "src/ModularCoreUpgradeable.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {DelayedRevealBatchMetadataERC721} from "src/extension/token/metadata/DelayedRevealBatchMetadataERC721.sol";

contract DelayedRevealExt is DelayedRevealBatchMetadataERC721 {
    function tokenIdRangeEnd(address token) external view returns (uint256[] memory) {
        return _delayedRevealBatchMetadataStorage().tokenIdRangeEnd[token];
    }

    function nextTokenIdRangeStart(address token) external view returns (uint256) {
        return _delayedRevealBatchMetadataStorage().nextTokenIdRangeStart[token];
    }

    function baseURIOfTokenIdRange(address token, uint256 rangeEnd) external view returns (string memory) {
        return _delayedRevealBatchMetadataStorage().baseURIOfTokenIdRange[token][rangeEnd];
    }

    function encryptedData(address token, uint256 rangeEnd) external view returns (bytes memory) {
        return _delayedRevealBatchMetadataStorage().encryptedData[token][rangeEnd];
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
        // Deterministic, canonical ERC1967Factory contract
        vm.etch(ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE);

        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC721Core(ERC1967FactoryConstants.ADDRESS, "test", "TEST", "", owner, extensions, extensionData);
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
        uint256[] memory rangeEnds = installedExtension.tokenIdRangeEnd(address(core));
        assertEq(rangeEnds.length, 1);
        assertEq(rangeEnds[0], 100);
        assertEq(installedExtension.nextTokenIdRangeStart(address(core)), 100);
        assertEq(installedExtension.baseURIOfTokenIdRange(address(core), 100), "ipfs://base/");
        assertEq(installedExtension.encryptedData(address(core), 100), "");

        // upload another batch
        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, "ipfs://base2/", "");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");
        assertEq(core.tokenURI(100), "ipfs://base2/100");
        assertEq(core.tokenURI(199), "ipfs://base2/199");

        // read state from the installed extension
        rangeEnds = installedExtension.tokenIdRangeEnd(address(core));
        assertEq(rangeEnds.length, 2);
        assertEq(rangeEnds[0], 100);
        assertEq(rangeEnds[1], 200);
        assertEq(installedExtension.nextTokenIdRangeStart(address(core)), 200);
        assertEq(installedExtension.baseURIOfTokenIdRange(address(core), 100), "ipfs://base/");
        assertEq(installedExtension.baseURIOfTokenIdRange(address(core), 200), "ipfs://base2/");
        assertEq(installedExtension.encryptedData(address(core), 100), "");
        assertEq(installedExtension.encryptedData(address(core), 200), "");
    }
}
