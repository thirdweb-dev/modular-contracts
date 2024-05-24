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
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {SimpleMetadataERC1155} from "src/extension/token/metadata/SimpleMetadataERC1155.sol";
import {SimpleMetadataERC721, SimpleMetadataStorage} from "src/extension/token/metadata/SimpleMetadataERC721.sol";

contract SimpleMetadataExt is SimpleMetadataERC1155 {
    function uris(address token, uint256 id) external view returns (string memory) {
        return SimpleMetadataStorage.data().uris[token][id];
    }
}

contract SimpleMetadataERC1155Test is Test {
    ERC1155Core public core;

    SimpleMetadataExt public extensionImplementation;
    SimpleMetadataExt public installedExtension;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        // Deterministic, canonical ERC1967Factory contract
        vm.etch(ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE);

        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC1155Core(ERC1967FactoryConstants.ADDRESS, "test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new SimpleMetadataExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory installedExtensions = core.getInstalledExtensions();
        installedExtension = SimpleMetadataExt(installedExtensions[0].implementation);
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
        assertEq(core.uri(3), "");

        // read state from the installed extension
        assertEq(installedExtension.uris(address(core), 1), "ipfs://base/1");
        assertEq(installedExtension.uris(address(core), 2), "ipfs://base/2");
        assertEq(installedExtension.uris(address(core), 3), "");
    }

    function test_revert_setTokenURI() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        SimpleMetadataExt(address(core)).setTokenURI(1, "ipfs://base/");
    }
}
