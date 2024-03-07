// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "@solady/utils/LibString.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {LazyMintHook, ERC721Hook} from "src/hook/metadata/LazyMintHook.sol";

contract LazyMintHookTest is Test {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Test params
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

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
        address MintHookImpl = address(new LazyMintHook());

        bytes memory initData = abi.encodeWithSelector(
            LazyMintHook.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address MintHookProxy = address(new EIP1967Proxy(MintHookImpl, initData));
        lazyMintHook = LazyMintHook(MintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit = new ERC721Core.InstallHookParams[](1);

        hooksToInstallOnInit[0].hook = IHook(address(lazyMintHook));

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
        vm.label(address(MintHookImpl), "LazyMintHook");
        vm.label(MintHookProxy, "ProxyLazyMintHook");
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

        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0);

        // Lazy mint tokens
        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG, abi.encodeWithSelector(LazyMintHook.lazyMint.selector, amount, baseURI, data)
        );

        // Query token URI
        for (uint256 i = 0; i < amount; i += 1) {
            tokenId = i;
            string memory tokenURI = erc721Core.tokenURI(tokenId);
            assertEq(tokenURI, string(abi.encodePacked(baseURI, tokenId.toString())));
        }

        assertEq(lazyMintHook.getBaseURICount(address(erc721Core)), 1);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0), amount);

        string memory baseURI2 = "ipfs://QmPVabcdvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";

        // Lazy mint morre tokens
        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG, abi.encodeWithSelector(LazyMintHook.lazyMint.selector, amount, baseURI2, data)
        );

        assertEq(lazyMintHook.getBaseURICount(address(erc721Core)), 2);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0), amount);
        assertEq(lazyMintHook.getBatchIdAtIndex(address(erc721Core), 1), amount * 2);
    }

    function test_lazymint_revert_mintingZeroTokens() public {
        uint256 amount = 0;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintHookZeroAmount.selector));
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG, abi.encodeWithSelector(LazyMintHook.lazyMint.selector, amount, baseURI, data)
        );
    }

    function test_lazymint_revert_queryingUnmintedTokenURI() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintHookInvalidTokenId.selector));
        erc721Core.tokenURI(0);
    }

    function test_lazymint_revert_queryingInvalidBatchId() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintHook.LazyMintHookInvalidIndex.selector));
        lazyMintHook.getBatchIdAtIndex(address(erc721Core), 0);
    }
}
