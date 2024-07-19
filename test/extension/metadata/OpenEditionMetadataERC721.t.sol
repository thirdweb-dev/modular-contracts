// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {
    OpenEditionMetadataERC721,
    OpenEditionMetadataStorage
} from "src/extension/token/metadata/OpenEditionMetadataERC721.sol";
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract OpenEditionMetadataExt is OpenEditionMetadataERC721 {

    function sharedMetadata() external view returns (SharedMetadata memory) {
        return OpenEditionMetadataStorage.data().sharedMetadata;
    }

    function createMetadataEdition(
        string memory name,
        string memory description,
        string memory imageURI,
        string memory animationURI,
        uint256 tokenOfEdition
    ) external pure returns (string memory) {
        return _createMetadataEdition(name, description, imageURI, animationURI, tokenOfEdition);
    }

}

contract OpenEditionMetadataERC721Test is Test {

    ERC721Core public core;

    OpenEditionMetadataExt public extensionImplementation;
    OpenEditionMetadataExt public installedExtension;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC721Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new OpenEditionMetadataExt();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory installedExtensions = core.getInstalledExtensions();
        installedExtension = OpenEditionMetadataExt(installedExtensions[0].implementation);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setSharedMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_setSharedMetadata() public {
        OpenEditionMetadataERC721.SharedMetadata memory sharedMetadata = OpenEditionMetadataERC721.SharedMetadata({
            name: "Test",
            description: "Test",
            imageURI: "https://test.com",
            animationURI: "https://test.com"
        });

        vm.prank(owner);
        OpenEditionMetadataExt(address(core)).setSharedMetadata(sharedMetadata);

        // read state from core
        assertEq(
            core.tokenURI(1),
            installedExtension.createMetadataEdition(
                sharedMetadata.name, sharedMetadata.description, sharedMetadata.imageURI, sharedMetadata.animationURI, 1
            )
        );
    }

    function test_revert_setSharedMetadata() public {
        OpenEditionMetadataERC721.SharedMetadata memory sharedMetadata;

        vm.expectRevert(0x82b42900); // `Unauthorized()`
        OpenEditionMetadataExt(address(core)).setSharedMetadata(sharedMetadata);
    }

}
