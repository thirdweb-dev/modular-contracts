// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "@murky/Merkle.sol";

import {Multicallable} from "@solady/utils/Multicallable.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";
import {MockOneHookImpl, MockFourHookImpl} from "test/mocks/MockHookImpl.sol";

import {ERC1155Core, ERC1155Initializable} from "src/core/token/ERC1155Core.sol";
import {AllowlistMintHookERC1155} from "src/hook/mint/AllowlistMintHookERC1155.sol";
import {LazyMintHook} from "src/hook/metadata/LazyMintHook.sol";
import {IERC1155} from "src/interface/eip/IERC1155.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {IInitCall} from "src/interface/common/IInitCall.sol";

/**
 *  This test showcases how users would use ERC-1155 contracts on the thirdweb platform.
 *
 *  CORE CONTRACTS:
 *
 *  Developers will deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-1155 Core contract.
 *
 *      - This contract is initializable, and meant to be used with proxy contracts.
 *      - Implements the token standard (and the respective token metadata standard).
 *      - Uses the role based permission model of the `Permission` contract.
 *      - Implements the `IHookInstaller` interface.
 *
 *  HOOKS:
 *
 *  Core contracts work with "hooks". There is a fixed set of 6 hooks supported by the core contract:
 *
 *      - BeforeMint: called before a token is minted in the ERC1155Core.mint call.
 *      - BeforeTransfer: called before a token is transferred in the ERC1155.transferFrom call.
 *      - BeforeBurn: called before a token is burned in the ERC1155.burn call.
 *      - BeforeApprove: called before the ERC1155.approve call.
 *      - Token URI: called when the ERC1155Metadata.uri function is called.
 *      - Royalty: called when the ERC2981.royaltyInfo function is called.
 *
 *  Each of these hooks is an external call made to a contract that implements the `IHook` interface.
 *
 *  The purpose of hooks is to allow developers to extend their contract's functionality by running custom logic
 *  right before a token is minted, transferred, burned, or approved, or for returning a token's metadata or royalty info.
 *
 *  Developers can install hooks into their core contracts, and uninstall hooks at any time.
 *
 *  UPGRADEABILITY:
 *
 *  thirdweb will publish upgradeable, 'shared state' hooks for developers (see src/erc1155/hooks/). These hook contracts are
 *  designed to be used by develpers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make
 *  beacon upgrades to developer contracts using these hooks.
 */
contract ERC1155CoreBenchmarkTest is Test {
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
    address public erc1155Implementation;
    address public hookProxyAddress;

    ERC1155Core public erc1155;
    AllowlistMintHookERC1155 public simpleClaimHook;
    LazyMintHook public lazyMintHook;

    // Token claim params
    uint256 public pricePerToken = 0.1 ether;
    uint256 public availableSupply = 100;

    function setUp() public {
        // Setup up to enabling minting on ERC-1155 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        cloneFactory = new CloneFactory();

        hookProxyAddress = address(new MinimalUpgradeableRouter(platformAdmin, address(new AllowlistMintHookERC1155())));
        simpleClaimHook = AllowlistMintHookERC1155(hookProxyAddress);

        address lazyMintHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new LazyMintHook())));
        lazyMintHook = LazyMintHook(lazyMintHookProxyAddress);

        erc1155Implementation = address(new ERC1155Core());

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        IInitCall.InitCall memory initCall;
        bytes memory data = abi.encodeWithSelector(
            ERC1155Core.initialize.selector, initCall, new address[](0), platformUser, "Test", "TST", "contractURI://"
        );
        erc1155 = ERC1155Core(cloneFactory.deployProxyByImplementation(erc1155Implementation, data, bytes32("salt")));

        vm.stopPrank();

        vm.label(address(erc1155), "ERC1155Core");
        vm.label(erc1155Implementation, "ERC1155CoreImpl");
        vm.label(hookProxyAddress, "AllowlistMintHookERC1155");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");

        vm.startPrank(platformUser);

        // Developer sets up token metadata and claim conditions: gas incurred by developer.
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory mdata = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            mdata[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32 root = merkle.getRoot(mdata);

        AllowlistMintHookERC1155.ClaimCondition memory condition = AllowlistMintHookERC1155.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        AllowlistMintHookERC1155.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        bytes[] memory multicallDataMintHook = new bytes[](2);

        multicallDataMintHook[0] =
            abi.encodeWithSelector(AllowlistMintHookERC1155.setDefaultFeeConfig.selector, 0, feeConfig);

        multicallDataMintHook[1] =
            abi.encodeWithSelector(AllowlistMintHookERC1155.setClaimCondition.selector, 0, condition);

        bytes memory initializeDataLazyMint =
            abi.encodeWithSelector(LazyMintHook.lazyMint.selector, 3, "https://example.com/", "");

        // Developer installs `AllowlistMintHookERC1155` hook
        erc1155.installHook(
            IHook(hookProxyAddress), abi.encodeWithSelector(Multicallable.multicall.selector, multicallDataMintHook)
        );
        erc1155.installHook(IHook(lazyMintHookProxyAddress), initializeDataLazyMint);

        vm.stopPrank();

        vm.deal(claimer, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC1155Core implementation contract.

        vm.pauseGasMetering();

        IInitCall.InitCall memory initCall;

        address impl = erc1155Implementation;
        bytes memory data = abi.encodeWithSelector(
            ERC1155Core.initialize.selector, initCall, new address[](0), platformUser, "Test", "TST", "contractURI://"
        );
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
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC1155Core claimContract = erc1155;
        address claimerAddress = claimer;
        uint256 tokenId = 0;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken}(claimerAddress, tokenId, quantityToClaim, encodedArgs);
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);
        uint256 quantityToClaim = 10;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC1155Core claimContract = erc1155;
        address claimerAddress = claimer;
        uint256 tokenId = 0;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken * 10}(claimerAddress, tokenId, quantityToClaim, encodedArgs);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Claimer claims one token
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);
        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);
        uint256 tokenId = 0;

        // Claim token
        vm.prank(claimer);
        erc1155.mint{value: pricePerToken}(claimer, tokenId, quantityToClaim, encodedArgs);

        address to = address(0x121212);
        address from = claimer;
        uint256 quantityToTransfer = 1;

        ERC1155Core erc1155Contract = erc1155;
        vm.prank(from);

        vm.resumeGasMetering();

        // Transfer token
        erc1155Contract.safeTransferFrom(from, to, tokenId, quantityToTransfer, "");
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        bytes4 sel = AllowlistMintHookERC1155.beforeMint.selector;
        address newImpl = address(new AllowlistMintHookERC1155());
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

        IHook mockHook = IHook(address(new MockOneHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook, bytes(""));
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook, bytes(""));
    }

    function test_uninstallOneHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook, bytes(""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook, bytes(""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }
}
