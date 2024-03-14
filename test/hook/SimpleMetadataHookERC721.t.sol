// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "@solady/utils/LibString.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {SimpleMetadataHook, ERC721Hook} from "src/hook/metadata/SimpleMetadataHook.sol";

contract SimpleMetadataHookTest is Test {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Test params
    uint256 public constant ON_TOKEN_URI_FLAG = 2 ** 5;

    // Participants
    address public platformAdmin = address(0x123);
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721Core;
    SimpleMetadataHook public metadataHook;

    function setUp() public {
        // Platform deploys metadata hook.
        address MintHookImpl = address(new SimpleMetadataHook());

        bytes memory initData = abi.encodeWithSelector(
            metadataHook.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address MintHookProxy = address(new EIP1967Proxy(MintHookImpl, initData));
        metadataHook = SimpleMetadataHook(MintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit = new ERC721Core.InstallHookParams[](1);

        hooksToInstallOnInit[0].hook = IHook(address(metadataHook));

        erc721Core = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        vm.stopPrank();

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");

        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(MintHookImpl), "metadataHook");
        vm.label(MintHookProxy, "ProxymetadataHook");
    }

    function test_setTokenURI_state() public {
        uint256 tokenId = 454;

        assertEq(erc721Core.tokenURI(tokenId), "");

        // Set token URI
        string memory tokenURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/454";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            ON_TOKEN_URI_FLAG, abi.encodeWithSelector(SimpleMetadataHook.setTokenURI.selector, tokenId, tokenURI)
        );

        assertEq(erc721Core.tokenURI(tokenId), tokenURI);

        string memory tokenURI2 = "ipfs://QmPVMveABCDEYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/454";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            ON_TOKEN_URI_FLAG, abi.encodeWithSelector(SimpleMetadataHook.setTokenURI.selector, tokenId, tokenURI2)
        );

        assertEq(erc721Core.tokenURI(tokenId), tokenURI2);
    }
}
