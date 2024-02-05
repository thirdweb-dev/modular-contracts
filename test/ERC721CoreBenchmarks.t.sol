// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import "src/lib/LibClone.sol";
import "src/common/UUPSUpgradeable.sol";

import { CloneFactory } from "src/infra/CloneFactory.sol";
import { EIP1967Proxy } from "src/infra/EIP1967Proxy.sol";
import { MinimalUpgradeableRouter } from "src/infra/MinimalUpgradeableRouter.sol";
import { MockOneHookImpl, MockFourHookImpl } from "test/mocks/MockHookImpl.sol";

import { ERC721Core, ERC721Initializable } from "src/core/token/ERC721Core.sol";
import { ERC721Hook, AllowlistMintHookERC721 } from "src/hook/mint/AllowlistMintHookERC721.sol";
import { LazyMintHookERC721 } from "src/hook/metadata/LazyMintHookERC721.sol";
import { RoyaltyHook } from "src/hook/royalty/RoyaltyHook.sol";
import { IERC721 } from "src/interface/eip/IERC721.sol";
import { IHook } from "src/interface/hook/IHook.sol";
import { IInitCall } from "src/interface/common/IInitCall.sol";

/**
 *  This test showcases how users would use ERC-721 contracts on the thirdweb platform.
 *
 *  CORE CONTRACTS:
 *
 *  Developers will deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-721 Core contract.
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
 *      - BeforeMint: called before a token is minted in the ERC721Core.mint call.
 *      - BeforeTransfer: called before a token is transferred in the ERC721.transferFrom call.
 *      - BeforeBurn: called before a token is burned in the ERC721.burn call.
 *      - BeforeApprove: called before the ERC721.approve call.
 *      - Token URI: called when the ERC721Metadata.tokenURI function is called.
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
 *  thirdweb will publish upgradeable, 'shared state' hooks for developers (see src/erc721/hooks/). These hook contracts are
 *  designed to be used by develpers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make
 *  beacon upgrades to developer contracts using these hooks.
 */
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
    AllowlistMintHookERC721 public simpleClaimHook;
    LazyMintHookERC721 public lazyMintHook;
    RoyaltyHook public royaltyHook;

    MockOneHookImpl public mockOneHook;
    MockFourHookImpl public mockFourHook;

    // Token claim params
    uint256 public pricePerToken = 0.1 ether;
    uint256 public availableSupply = 100;

    function setUp() public {
        // Setup up to enabling minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        cloneFactory = new CloneFactory();

        hookProxyAddress = cloneFactory.deployERC1967(
            address(new AllowlistMintHookERC721()),
            abi.encodeWithSelector(AllowlistMintHookERC721.initialize.selector, platformAdmin)
        );
        simpleClaimHook = AllowlistMintHookERC721(hookProxyAddress);
        assertEq(simpleClaimHook.getNextTokenIdToMint(address(erc721)), 0);

        address lazyMintHookProxyAddress = cloneFactory.deployERC1967(
            address(new LazyMintHookERC721()),
            abi.encodeWithSelector(AllowlistMintHookERC721.initialize.selector, platformAdmin)
        );
        lazyMintHook = LazyMintHookERC721(lazyMintHookProxyAddress);

        address royaltyHookProxyAddress = address(
            new MinimalUpgradeableRouter(platformAdmin, address(new RoyaltyHook()))
        );
        royaltyHook = RoyaltyHook(royaltyHookProxyAddress);

        address mockAddress = address(
            new EIP1967Proxy(
                address(new MockOneHookImpl()),
                abi.encodeWithSelector(MockOneHookImpl.initialize.selector, platformAdmin)
            )
        );
        mockOneHook = MockOneHookImpl(mockAddress);

        mockAddress = address(
            new EIP1967Proxy(
                address(new MockFourHookImpl()),
                abi.encodeWithSelector(MockFourHookImpl.initialize.selector, platformAdmin)
            )
        );
        mockFourHook = MockFourHookImpl(mockAddress);

        erc721Implementation = address(new ERC721Core());

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        IInitCall.InitCall memory initCall;
        bytes memory data = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            new address[](0),
            platformUser,
            "Test",
            "TST",
            "contractURI://"
        );
        erc721 = ERC721Core(cloneFactory.deployProxyByImplementation(erc721Implementation, data, bytes32("salt")));

        vm.stopPrank();

        vm.label(address(erc721), "ERC721Core");
        vm.label(erc721Implementation, "ERC721CoreImpl");
        vm.label(hookProxyAddress, "AllowlistMintHookERC721");
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

        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        simpleClaimHook.setClaimCondition(address(erc721), condition);

        AllowlistMintHookERC721.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        simpleClaimHook.setDefaultFeeConfig(address(erc721), feeConfig);

        // Developer installs `AllowlistMintHookERC721` hook
        erc721.installHook(IHook(hookProxyAddress));
        erc721.installHook(IHook(lazyMintHookProxyAddress));

        vm.stopPrank();

        vm.deal(claimer, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        IInitCall.InitCall memory initCall;

        address impl = erc721Implementation;
        bytes memory data = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            new address[](0),
            platformUser,
            "Test",
            "TST",
            "contractURI://"
        );
        bytes32 salt = bytes32("salt");

        vm.resumeGasMetering();

        cloneFactory.deployProxyByImplementation(impl, data, salt);
    }

    function test_deployEndUserContract_withHooks() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        address[] memory hooks = new address[](3);
        hooks[0] = address(simpleClaimHook);
        hooks[1] = address(lazyMintHook);
        hooks[2] = address(royaltyHook);

        IInitCall.InitCall memory initCall;

        address impl = erc721Implementation;
        bytes memory data = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            hooks,
            platformUser,
            "Test",
            "TST",
            "contractURI://"
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
        claimContract.mint{ value: pricePerToken }(claimerAddress, quantityToClaim, encodedArgs);
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
        claimContract.mint{ value: pricePerToken * 10 }(claimerAddress, quantityToClaim, encodedArgs);
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
        erc721.mint{ value: pricePerToken }(claimer, quantityToClaim, encodedArgs);

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

    function test_performUpgrade() public {
        vm.pauseGasMetering();

        address newAdmin = address(0x7890);
        address newImpl = address(new AllowlistMintHookERC721());
        address currentAdmin = platformAdmin;
        UUPSUpgradeable proxy = UUPSUpgradeable(payable(hookProxyAddress));

        vm.prank(currentAdmin);

        vm.resumeGasMetering();

        // Perform upgrade
        proxy.upgradeToAndCall(newImpl, "");
        // assertEq(ERC721Hook(address(proxy)).admin(), newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
            ADD NEW FUNCTIONALITY AND UPDATE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_installOneHook() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockOneHook);
        IHook mockHook = IHook(mockAddress);

        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockFourHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockOneHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockFourHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }
}
