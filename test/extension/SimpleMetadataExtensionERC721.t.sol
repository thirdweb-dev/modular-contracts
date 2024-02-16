// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {LibString} from "src/lib/LibString.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {SimpleMetadataExtension, ERC721Extension} from "src/extension/metadata/SimpleMetadataExtension.sol";

contract SimpleMetadataExtensionTest is Test {
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
    SimpleMetadataExtension public metadataExtension;

    function setUp() public {
        // Platform deploys metadata extension.
        address mintExtensionImpl = address(new SimpleMetadataExtension());

        bytes memory initData = abi.encodeWithSelector(
            metadataExtension.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintExtensionProxy = address(new EIP1967Proxy(mintExtensionImpl, initData));
        metadataExtension = SimpleMetadataExtension(mintExtensionProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallExtensions = new address[](1);
        preinstallExtensions[0] = address(metadataExtension);

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
        vm.label(address(mintExtensionImpl), "metadataExtension");
        vm.label(mintExtensionProxy, "ProxymetadataExtension");
    }

    function test_setTokenURI_state() public {
        uint256 tokenId = 454;

        assertEq(erc721Core.tokenURI(tokenId), "");

        // Set token URI
        string memory tokenURI = "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/454";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG, 0, abi.encodeWithSelector(SimpleMetadataExtension.setTokenURI.selector, tokenId, tokenURI)
        );

        assertEq(erc721Core.tokenURI(tokenId), tokenURI);

        string memory tokenURI2 = "ipfs://QmPVMveABCDEYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/454";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            TOKEN_URI_FLAG, 0, abi.encodeWithSelector(SimpleMetadataExtension.setTokenURI.selector, tokenId, tokenURI2)
        );

        assertEq(erc721Core.tokenURI(tokenId), tokenURI2);
    }
}
