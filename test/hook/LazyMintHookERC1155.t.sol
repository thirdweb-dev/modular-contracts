// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "src/lib/LibString.sol";

import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {LazyMintHookERC1155, ERC1155Hook} from "src/hook/metadata/LazyMintHookERC1155.sol";

contract LazyMintHookERC1155Test is Test {

    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC1155Core public erc1155Core;
    LazyMintHookERC1155 public lazyMintHook;

    // Test events
    event TokensLazyMinted(
        address indexed token, uint256 indexed startTokenId, uint256 endTokenId, string baseURI, bytes encryptedBaseURI
    );

    function setUp() public {

        // Platform deploys lazy mint hook.
        address mintHookImpl = address(new LazyMintHookERC1155());

        bytes memory initData = abi.encodeWithSelector(
            LazyMintHookERC1155.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintHookProxy = address(new EIP1967Proxy(mintHookImpl, initData));
        lazyMintHook = LazyMintHookERC1155(mintHookProxy);

        // Platform deploys ERC1155 core implementation and clone factory.
        address erc1155CoreImpl = address(new ERC1155Core());
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC1155Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(lazyMintHook);

        bytes memory erc1155InitData = abi.encodeWithSelector(
            ERC1155Core.initialize.selector,
            initCall,
            preinstallHooks,
            developer, // core contract admin
            "Test ERC1155",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc1155Core = ERC1155Core(factory.deployProxyByImplementation(erc1155CoreImpl, erc1155InitData, bytes32("salt")));

        vm.stopPrank();

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");
        
        vm.label(address(erc1155Core), "ERC1155Core");
        vm.label(address(mintHookImpl), "LazyMintHookERC1155");
        vm.label(mintHookProxy, "ProxyLazyMintHookERC1155");
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_lazymint_state() public {

        uint256 tokenId = 0;
        vm.expectRevert();
        erc1155Core.uri(tokenId);


        uint256 amount = 100;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        assertEq(lazyMintHook.getBaseURICount(address(erc1155Core)), 0);

        vm.expectRevert(abi.encodeWithSelector(LazyMintHookERC1155.LazyMintMetadataHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc1155Core), 0);

        // Lazy mint tokens
        vm.prank(developer);
        lazyMintHook.lazyMint(address(erc1155Core), amount, baseURI, data);

        // Query token URI
        for(uint256 i = 0; i < amount; i += 1) {
            tokenId = i;
            string memory tokenURI = erc1155Core.uri(tokenId);
            assertEq(tokenURI, string(abi.encodePacked(baseURI, tokenId.toString())));
        }

        assertEq(lazyMintHook.getBaseURICount(address(erc1155Core)), 1);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc1155Core), 0), amount);

        string memory baseURI2 = "ipfs://QmPVabcdvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";

        // Lazy mint morre tokens
        vm.prank(developer);
        lazyMintHook.lazyMint(address(erc1155Core), amount, baseURI2, data);

        assertEq(lazyMintHook.getBaseURICount(address(erc1155Core)), 2);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc1155Core), 0), amount);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc1155Core), 1), amount * 2);
    }

    function test_lazymint_revert_mintingZeroTokens() public {
        uint256 amount = 0;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(LazyMintHookERC1155.LazyMintMetadataHookZeroAmount.selector));
        lazyMintHook.lazyMint(address(erc1155Core), amount, baseURI, data);
    }
    
    function test_lazymint_revert_queryingUnmintedTokenURI() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHookERC1155.LazyMintMetadataHookInvalidTokenId.selector));
        erc1155Core.uri(0);
    }

    function test_lazymint_revert_queryingInvalidBatchId() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHookERC1155.LazyMintMetadataHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc1155Core), 0);
    }
}