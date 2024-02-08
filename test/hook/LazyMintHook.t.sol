// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "src/lib/LibString.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {LazyMintHook, ERC721Hook} from "src/hook/metadata/LazyMintHook.sol";

contract LazyMintHookTest is Test {

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
    LazyMintHook public lazyMintHook;

    // Test events
    event TokensLazyMinted(
        address indexed token, uint256 indexed startTokenId, uint256 endTokenId, string baseURI, bytes encryptedBaseURI
    );

    function setUp() public {

        // Platform deploys lazy mint hook.
        address mintHookImpl = address(new LazyMintHook());

        bytes memory initData = abi.encodeWithSelector(
            LazyMintHook.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintHookProxy = address(new EIP1967Proxy(mintHookImpl, initData));
        lazyMintHook = LazyMintHook(mintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(lazyMintHook);

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
        vm.label(address(mintHookImpl), "LazyMintHook");
        vm.label(mintHookProxy, "ProxyLazyMintHook");
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_lazymint_state() public {

        uint256 tokenId = 0;
        vm.expectRevert();
        erc721Core.tokenURI(tokenId);


        uint256 amount = 100;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        assertEq(lazyMintHook.getBaseURICount(address(erc721Core)), 0);

        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintMetadataHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0);

        // Lazy mint tokens
        vm.prank(developer);
        lazyMintHook.lazyMint(address(erc721Core), amount, baseURI, data);

        // Query token URI
        for(uint256 i = 0; i < amount; i += 1) {
            tokenId = i;
            string memory tokenURI = erc721Core.tokenURI(tokenId);
            assertEq(tokenURI, string(abi.encodePacked(baseURI, tokenId.toString())));
        }

        assertEq(lazyMintHook.getBaseURICount(address(erc721Core)), 1);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0), amount);

        string memory baseURI2 = "ipfs://QmPVabcdvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";

        // Lazy mint morre tokens
        vm.prank(developer);
        lazyMintHook.lazyMint(address(erc721Core), amount, baseURI2, data);

        assertEq(lazyMintHook.getBaseURICount(address(erc721Core)), 2);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0), amount);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 1), amount * 2);
    }

    function test_lazymint_revert_mintingZeroTokens() public {
        uint256 amount = 0;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintMetadataHookZeroAmount.selector));
        lazyMintHook.lazyMint(address(erc721Core), amount, baseURI, data);
    }
    
    function test_lazymint_revert_queryingUnmintedTokenURI() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintMetadataHookInvalidTokenId.selector));
        erc721Core.tokenURI(0);
    }

    function test_lazymint_revert_queryingInvalidBatchId() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintMetadataHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0);
    }
}