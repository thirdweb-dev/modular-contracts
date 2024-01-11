// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";
import {MockOneHookImpl, MockFourHookImpl} from "test/mocks/MockHookImpl.sol";

import {ERC721Core, ERC721Initializable} from "src/erc721/ERC721Core.sol";
import {AllowlistMintHook} from "src/erc721/hooks/AllowlistMintHook.sol";
import {LazyMintMetadataHook} from "src/erc721/hooks/LazyMintMetadataHook.sol";
import {IERC721} from "src/interface/erc721/IERC721.sol";
import {ITokenHook} from "src/interface/extension/ITokenHook.sol";

contract ERC721CoreBenchmarkTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Test util
    CloneFactory public cloneFactory;

    // Target test contracts
    address public erc721Implementation;
    address public hookProxyAddress;

    ERC721Core public erc721;
    AllowlistMintHook public simpleClaimHook;
    LazyMintMetadataHook public lazyMintHook;

    // Token claim params
    uint256 public pricePerToken = 0.1 ether;
    uint256 public availableSupply = 100;

    function setUp() public {
        // Setup up to enabling minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        cloneFactory = new CloneFactory();

        hookProxyAddress = address(new MinimalUpgradeableRouter(platformAdmin, address(new AllowlistMintHook())));
        simpleClaimHook = AllowlistMintHook(hookProxyAddress);
        assertEq(simpleClaimHook.getNextTokenIdToMint(address(erc721)), 0);

        address lazyMintHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new LazyMintMetadataHook())));
        lazyMintHook = LazyMintMetadataHook(lazyMintHookProxyAddress);

        erc721Implementation = address(new ERC721Core());

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        bytes memory data = abi.encodeWithSelector(ERC721Core.initialize.selector, platformUser, "Test", "TST", "contractURI://");
        erc721 = ERC721Core(cloneFactory.deployProxyByImplementation(erc721Implementation, data, bytes32("salt")));

        vm.stopPrank();

        vm.label(address(erc721), "ERC721Core");
        vm.label(erc721Implementation, "ERC721CoreImpl");
        vm.label(hookProxyAddress, "AllowlistMintHook");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");

        // Developer sets up token metadata and claim conditions: gas incurred by developer.
        vm.startPrank(platformUser);

        lazyMintHook.lazyMint(address(erc721), 10_000, "https://example.com/", "");

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

        AllowlistMintHook.ClaimCondition memory condition = AllowlistMintHook.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        simpleClaimHook.setClaimCondition(address(erc721), condition);

        // Developer installs `AllowlistMintHook` hook
        erc721.installHook(ITokenHook(hookProxyAddress));

        vm.stopPrank();

        vm.deal(claimer, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        address impl = erc721Implementation;
        bytes memory data = abi.encodeWithSelector(ERC721Core.initialize.selector, platformUser, "Test", "TST", "contractURI://");
        bytes32 salt = bytes32("salt");

        vm.resumeGasMetering();

        cloneFactory.deployProxyByImplementation(impl, data, salt);
    }

    /*//////////////////////////////////////////////////////////////
                        MINT 1 TOKEN AND 10 TOKENS
    //////////////////////////////////////////////////////////////*/

    function test_mintOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));
        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC721Core claimContract = erc721;
        address claimerAddress = claimer;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: 0.1 ether}(claimerAddress, quantityToClaim, encodedArgs);
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));
        uint256 quantityToClaim = 10;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC721Core claimContract = erc721;
        address claimerAddress = claimer;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: 1 ether}(claimerAddress, quantityToClaim, encodedArgs);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Claimer claims one token
        string[] memory claimInputs = new string[](2);
        claimInputs[0] = "node";
        claimInputs[1] = "test/scripts/getProof.ts";

        bytes memory claimResult = vm.ffi(claimInputs);
        bytes32[] memory proofs = abi.decode(claimResult, (bytes32[]));
        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);

        // Claim token
        vm.prank(claimer);
        erc721.mint{value: 0.1 ether}(claimer, quantityToClaim, encodedArgs);

        uint256 tokenId = 0;
        address to = address(0x121212);
        address from = claimer;

        ERC721Core erc721Contract = erc721;
        vm.prank(from);

        vm.resumeGasMetering();

        // Transfer token
        erc721Contract.transferFrom(from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        bytes4 sel = AllowlistMintHook.beforeMint.selector;
        address newImpl = address(new AllowlistMintHook());
        address proxyAdmin = platformAdmin;
        MinimalUpgradeableRouter proxy = MinimalUpgradeableRouter(payable(hookProxyAddress));

        vm.prank(proxyAdmin);

        vm.resumeGasMetering();

        // Perform upgrade
        proxy.setImplementationForFunction(sel, newImpl);
    }

    /*//////////////////////////////////////////////////////////////
            ADD NEW FUNCTIONALITY AND UPDATE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_installOneHook() public {
        vm.pauseGasMetering();

        ITokenHook mockHook = ITokenHook(address(new MockOneHookImpl()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        ITokenHook mockHook = ITokenHook(address(new MockFourHookImpl()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(ITokenHook(hookProxyAddress));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        ITokenHook mockHook = ITokenHook(address(new MockOneHookImpl()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        ITokenHook mockHook = ITokenHook(address(new MockFourHookImpl()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(ITokenHook(hookProxyAddress));

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }
}
