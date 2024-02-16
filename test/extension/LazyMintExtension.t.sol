// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "src/lib/LibString.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {LazyMintExtension, ERC721Extension} from "src/extension/metadata/LazyMintExtension.sol";

contract LazyMintExtensionTest is Test {

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
    LazyMintExtension public lazyMintExtension;

    // Test events
    event TokensLazyMinted(
        address indexed token, uint256 indexed startTokenId, uint256 endTokenId, string baseURI, bytes encryptedBaseURI
    );

    function setUp() public {

        // Platform deploys lazy mint extension.
        address mintExtensionImpl = address(new LazyMintExtension());

        bytes memory initData = abi.encodeWithSelector(
            LazyMintExtension.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintExtensionProxy = address(new EIP1967Proxy(mintExtensionImpl, initData));
        lazyMintExtension = LazyMintExtension(mintExtensionProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallExtensions = new address[](1);
        preinstallExtensions[0] = address(lazyMintExtension);

        bytes memory erc721InitData = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            preinstallExtensions,
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
        vm.label(address(mintExtensionImpl), "LazyMintExtension");
        vm.label(mintExtensionProxy, "ProxyLazyMintExtension");
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

        assertEq(lazyMintExtension.getBaseURICount(address(erc721Core)), 0);

        vm.expectRevert(abi.encodeWithSelector(LazyMintExtension.LazyMintExtensionInvalidIndex.selector));
        lazyMintExtension.getBatchIdAtIndex(address(erc721Core), 0);

        // Lazy mint tokens
        vm.prank(developer);
        erc721Core.hookFunctionWrite(TOKEN_URI_FLAG, 0, abi.encodeWithSelector(LazyMintExtension.lazyMint.selector, amount, baseURI, data));

        // Query token URI
        for(uint256 i = 0; i < amount; i += 1) {
            tokenId = i;
            string memory tokenURI = erc721Core.tokenURI(tokenId);
            assertEq(tokenURI, string(abi.encodePacked(baseURI, tokenId.toString())));
        }

        assertEq(lazyMintExtension.getBaseURICount(address(erc721Core)), 1);
        assertEq(lazyMintExtension.getBatchIdAtIndex(address(erc721Core), 0), amount);

        string memory baseURI2 = "ipfs://QmPVabcdvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";

        // Lazy mint morre tokens
        vm.prank(developer);
        erc721Core.hookFunctionWrite(TOKEN_URI_FLAG, 0, abi.encodeWithSelector(LazyMintExtension.lazyMint.selector, amount, baseURI2, data));

        assertEq(lazyMintExtension.getBaseURICount(address(erc721Core)), 2);
        assertEq(lazyMintExtension.getBatchIdAtIndex(address(erc721Core), 0), amount);
        assertEq(lazyMintExtension.getBatchIdAtIndex(address(erc721Core), 1), amount * 2);
    }

    function test_lazymint_revert_mintingZeroTokens() public {
        uint256 amount = 0;
        string memory baseURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/";
        bytes memory data = bytes("");

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(LazyMintExtension.LazyMintExtensionZeroAmount.selector));
        erc721Core.hookFunctionWrite(TOKEN_URI_FLAG, 0, abi.encodeWithSelector(LazyMintExtension.lazyMint.selector, amount, baseURI, data));
    }
    
    function test_lazymint_revert_queryingUnmintedTokenURI() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintExtension.LazyMintExtensionInvalidTokenId.selector));
        erc721Core.tokenURI(0);
    }

    function test_lazymint_revert_queryingInvalidBatchId() public {
        // E.g. Nothing minted yet
        vm.expectRevert(abi.encodeWithSelector(LazyMintExtension.LazyMintExtensionInvalidIndex.selector));
        lazyMintExtension.getBatchIdAtIndex(address(erc721Core), 0);
    }
}