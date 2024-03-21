// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";
import {IHookInstaller} from "src/interface/hook/IHookInstaller.sol";
import {IMintRequest} from "src/interface/common/IMintRequest.sol";

import {EmptyHookERC20} from "test/mocks/EmptyHook.sol";
import {MockOneHookImpl, MockFourHookImpl} from "test/mocks/MockHookImpl.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {IERC20Hook} from "src/interface/hook/IERC20Hook.sol";

contract ERC20CoreBenchmarkTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC20Core public erc20;
    address public hookProxyAddress;

    IERC20Hook.MintRequest public mintRequest;

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    function setUp() public {
        // Setup: minting on ERC-20 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        hookProxyAddress = address(
            new EIP1967Proxy(
                address(new EmptyHookERC20()),
                abi.encodeWithSelector(
                    EmptyHookERC20.initialize.selector,
                    platformAdmin // upgradeAdmin
                )
            )
        );

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        ERC20Core.OnInitializeParams memory onInitializeCall;
        ERC20Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc20 = new ERC20Core(
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        // Developer installs `EmptyHookERC20` hook
        erc20.installHook(IHookInstaller.InstallHookParams(IHook(hookProxyAddress), 0, bytes("")));

        vm.stopPrank();

        vm.label(address(erc20), "ERC20Core");
        vm.label(hookProxyAddress, "EmptyHookERC20");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC20Core implementation contract.

        vm.pauseGasMetering();

        ERC20Core.OnInitializeParams memory onInitializeCall;
        ERC20Core.InstallHookParams[] memory hooksToInstallOnInit;

        vm.resumeGasMetering();

        ERC20Core core = new ERC20Core(
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );
    }

    /*//////////////////////////////////////////////////////////////
                        MINT 1 TOKEN AND 10 TOKENS
    //////////////////////////////////////////////////////////////*/

    function test_mintOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        mintRequest.token = address(erc20);
        mintRequest.minter = claimer;
        mintRequest.quantity = 1 ether;

        IERC20Hook.MintRequest memory req = mintRequest;
        ERC20Core core = erc20;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(req);
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        mintRequest.token = address(erc20);
        mintRequest.minter = claimer;
        mintRequest.quantity = 10 ether;

        IERC20Hook.MintRequest memory req = mintRequest;
        ERC20Core core = erc20;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(req);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        mintRequest.token = address(erc20);
        mintRequest.minter = claimer;
        mintRequest.quantity = 10 ether;

        IERC20Hook.MintRequest memory req = mintRequest;
        ERC20Core core = erc20;

        core.mint(req);

        address to = address(0x121212);
        vm.prank(mintRequest.minter);

        vm.resumeGasMetering();

        // Transfer token
        core.transfer(to, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        address newImpl = address(new EmptyHookERC20());
        address proxyAdmin = platformAdmin;
        EmptyHookERC20 proxy = EmptyHookERC20(payable(hookProxyAddress));

        vm.prank(proxyAdmin);

        vm.resumeGasMetering();

        // Perform upgrade
        proxy.upgradeToAndCall(address(newImpl), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
            ADD NEW FUNCTIONALITY AND UPDATE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_installOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImpl()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(BEFORE_MINT_FLAG);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImpl()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(BEFORE_TRANSFER_FLAG);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(BEFORE_MINT_FLAG);

        vm.prank(platformUser);
        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(BEFORE_TRANSFER_FLAG);
    }
}
