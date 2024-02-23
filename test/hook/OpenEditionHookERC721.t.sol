// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { CloneFactory } from "src/infra/CloneFactory.sol";
import { EIP1967Proxy } from "src/infra/EIP1967Proxy.sol";

import { LibString } from "@solady/utils/LibString.sol";

import { ERC721Core, HookInstaller } from "src/core/token/ERC721Core.sol";
import { OpenEditionHookERC721, ERC721Hook } from "src/hook/metadata/OpenEditionHookERC721.sol";
import { ISharedMetadata } from "src/interface/common/ISharedMetadata.sol";
import { NFTMetadataRenderer } from "src/lib/NFTMetadataRenderer.sol";

contract OpenEditionHookERC721Test is Test {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721Core;
    OpenEditionHookERC721 public metadataHook;

    // Test params
    uint256 public constant TOKEN_URI_FLAG = 2**5;
    ISharedMetadata.SharedMetadataInfo public sharedMetadata;

    function setUp() public {
        // Platform deploys metadata hook.
        address hookImpl = address(new OpenEditionHookERC721());

        bytes memory initData = abi.encodeWithSelector(
            metadataHook.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address hookProxy = address(new EIP1967Proxy(hookImpl, initData));
        metadataHook = OpenEditionHookERC721(hookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(metadataHook);

        bytes memory erc721InitData = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            preinstallHooks,
            developer, // core contract admin
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc721Core = ERC721Core(factory.deployProxyByImplementation(erc721CoreImpl, erc721InitData, bytes32("salt")));

        vm.stopPrank();

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");

        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(hookImpl), "metadataHookImpl");
        vm.label(hookProxy, "ProxymetadataHook");

        sharedMetadata = ISharedMetadata.SharedMetadataInfo({
            name: "Test",
            description: "Test",
            imageURI: "https://test.com",
            animationURI: "https://test.com"
        });
    }

    function test_setSharedMetadata_state() public {
        uint256 tokenId = 454;

        assertEq(
            erc721Core.tokenURI(tokenId),
            NFTMetadataRenderer.createMetadataEdition({
                name: "",
                description: "",
                imageURI: "",
                animationURI: "",
                tokenOfEdition: tokenId
            })
        );

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG,
            0,
            abi.encodeWithSelector(OpenEditionHookERC721.setSharedMetadata.selector, sharedMetadata)
        );

        assertEq(
            erc721Core.tokenURI(tokenId),
            NFTMetadataRenderer.createMetadataEdition({
                name: sharedMetadata.name,
                description: sharedMetadata.description,
                imageURI: sharedMetadata.imageURI,
                animationURI: sharedMetadata.animationURI,
                tokenOfEdition: tokenId
            })
        );

        // test for arbitrary tokenId
        assertEq(
            erc721Core.tokenURI(1337),
            NFTMetadataRenderer.createMetadataEdition({
                name: sharedMetadata.name,
                description: sharedMetadata.description,
                imageURI: sharedMetadata.imageURI,
                animationURI: sharedMetadata.animationURI,
                tokenOfEdition: 1337
            })
        );
    }

    function test_revert_setSharedMetadata_notAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(HookInstaller.HookInstallerUnauthorizedWrite.selector));
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG,
            0,
            abi.encodeWithSelector(OpenEditionHookERC721.setSharedMetadata.selector, sharedMetadata)
        );
    }
}
