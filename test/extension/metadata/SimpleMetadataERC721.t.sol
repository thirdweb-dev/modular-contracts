// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularModule} from "src/ModularModule.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {SimpleMetadataERC721, SimpleMetadataStorage} from "src/module/token/metadata/SimpleMetadataERC721.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";

contract SimpleMetadataExt is SimpleMetadataERC721 {}

contract SimpleMetadataERC721Test is Test {

    ERC721Core public core;

    SimpleMetadataExt public moduleImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
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
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(2), "ipfs://base/2");

        vm.expectRevert(abi.encodeWithSelector(SimpleMetadataERC721.MetadataNoMetadataForTokenId.selector));
        core.tokenURI(3);
    }

    function test_revert_setTokenURI() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        SimpleMetadataExt(address(core)).setTokenURI(1, "ipfs://base/");
    }

}
