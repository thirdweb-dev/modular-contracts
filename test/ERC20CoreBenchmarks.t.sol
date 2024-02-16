// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";
import {MockOneHookImpl20, MockFourHookImpl20} from "test/mocks/mockHookImpl.sol";

import {ERC20Core, ERC20Initializable} from "src/core/token/ERC20Core.sol";
import {AllowlistMintHookERC20} from "src/hook/mint/AllowlistMintHookERC20.sol";
import {IERC20} from "src/interface/eip/IERC20.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {IInitCall} from "src/interface/common/IInitCall.sol";

/**
 *  This test showcases how users would use ERC-20 contracts on the thirdweb platform.
 *
 *  CORE CONTRACTS:
 *
 *  Developers will deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-20 Core contract.
 *
 *      - This contract is initializable, and meant to be used with proxy contracts.
 *      - Implements the token standard (and the respective token metadata standard).
 *      - Uses the role based permission model of the `Permission` contract.
 *      - Implements the `IHookInstaller` interface.
 *
 *  HOOKS:
 *
 *  Core contracts work with "hooks". There is a fixed set of 4 hooks supported by the core contract:
 *
 *      - BeforeMint: called before a token is minted in the ERC20Core.mint call.
 *      - BeforeTransfer: called before a token is transferred in the ERC20.transfer call.
 *      - BeforeBurn: called before a token is burned in the ERC20.burn call.
 *      - BeforeApprove: called before the ERC20.approve call.
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
 *  thirdweb will publish upgradeable, 'shared state' hooks for developers (see src/erc20/hooks/). These hook contracts are
 *  designed to be used by develpers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make
 *  beacon upgrades to developer contracts using these hooks.
 */
contract ERC20CoreBenchmarkTest is Test {
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
    address public erc20Implementation;
    address public hookProxyAddress;

    ERC20Core public erc20;
    AllowlistMintHookERC20 public simpleClaimHook;

    // Token claim params
    uint256 public pricePerToken = 1 ether;
    uint256 public availableSupply = 100 ether;

    function setUp() public {
        // Setup up to enabling minting on ERC-20 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        cloneFactory = new CloneFactory();

        hookProxyAddress = address(new MinimalUpgradeableRouter(platformAdmin, address(new AllowlistMintHookERC20())));
        simpleClaimHook = AllowlistMintHookERC20(hookProxyAddress);

        erc20Implementation = address(new ERC20Core());

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        IInitCall.InitCall memory initCall;
        bytes memory data = abi.encodeWithSelector(
            ERC20Core.initialize.selector, initCall, new address[](0), platformUser, "Test", "TST", "contractURI://"
        );
        erc20 = ERC20Core(cloneFactory.deployProxyByImplementation(erc20Implementation, data, bytes32("salt")));

        vm.stopPrank();

        vm.label(address(erc20), "ERC20Core");
        vm.label(erc20Implementation, "ERC20CoreImpl");
        vm.label(hookProxyAddress, "AllowlistMintHookERC20");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");

        // Developer installs `AllowlistMintHookERC20` hook
        vm.startPrank(platformUser);
        erc20.installHook(IHook(hookProxyAddress));

        // Developer sets up token metadata and claim conditions: gas incurred by developer.
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

        AllowlistMintHookERC20.ClaimCondition memory condition = AllowlistMintHookERC20.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });
        erc20.hookFunctionWrite(
            erc20.BEFORE_MINT_FLAG(),
            0,
            abi.encodeWithSelector(AllowlistMintHookERC20.setClaimCondition.selector, condition)
        );

        AllowlistMintHookERC20.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        erc20.hookFunctionWrite(
            erc20.BEFORE_MINT_FLAG(),
            0,
            abi.encodeWithSelector(AllowlistMintHookERC20.setDefaultFeeConfig.selector, feeConfig)
        );

        vm.stopPrank();

        vm.deal(claimer, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC20Core implementation contract.

        vm.pauseGasMetering();

        IInitCall.InitCall memory initCall;

        address impl = erc20Implementation;
        bytes memory data = abi.encodeWithSelector(
            ERC20Core.initialize.selector, initCall, new address[](0), platformUser, "Test", "TST", "contractURI://"
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
        uint256 quantityToClaim = 1 ether;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC20Core claimContract = erc20;
        address claimerAddress = claimer;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken}(claimerAddress, quantityToClaim, encodedArgs);
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));
        uint256 quantityToClaim = 10 ether;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC20Core claimContract = erc20;
        address claimerAddress = claimer;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken * 10}(claimerAddress, quantityToClaim, encodedArgs);
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
        uint256 quantityToClaim = 1 ether;

        bytes memory encodedArgs = abi.encode(proofs);

        // Claim token
        vm.prank(claimer);
        erc20.mint{value: pricePerToken}(claimer, quantityToClaim, encodedArgs);

        address to = address(0x121212);
        address from = claimer;

        ERC20Core erc20Contract = erc20;
        vm.prank(from);

        vm.resumeGasMetering();

        // Transfer token
        erc20Contract.transfer(to, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        bytes4 sel = AllowlistMintHookERC20.beforeMint.selector;
        address newImpl = address(new AllowlistMintHookERC20());
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

        IHook mockHook = IHook(address(new MockOneHookImpl20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(mockHook);
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImpl20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(IHook(hookProxyAddress));

        vm.prank(platformUser);
        hookConsumer.installHook(mockHook);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(mockHook);
    }
}
