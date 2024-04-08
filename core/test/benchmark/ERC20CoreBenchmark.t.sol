// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IHook} from "src/interface/IHook.sol";
import {IHookInstaller} from "src/interface/IHookInstaller.sol";
import {HookFlagsDirectory} from "src/hook/HookFlagsDirectory.sol";

import {MockHookERC20, MockOneHookImplERC20, MockFourHookImplERC20} from "test/mocks/MockHook.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";

contract ERC20CoreBenchmarkTest is Test, HookFlagsDirectory {
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

    function setUp() public {
        // Setup: minting on ERC-20 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        hookProxyAddress = address(
            new EIP1967Proxy(
                address(new MockHookERC20()),
                abi.encodeWithSelector(
                    MockHookERC20.initialize.selector,
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

        // Developer installs `MockHookERC20` hook
        erc20.installHook(IHookInstaller.InstallHookParams(hookProxyAddress, 0, bytes("")));

        vm.stopPrank();

        vm.label(address(erc20), "ERC20Core");
        vm.label(hookProxyAddress, "MockHookERC20");
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
        address claimerAddress = claimer;
        uint256 quantity = 1 ether;
        ERC20Core core = erc20;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, quantity, "");
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        address claimerAddress = claimer;
        uint256 quantity = 10 ether;
        ERC20Core core = erc20;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, quantity, "");
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        address claimerAddress = claimer;
        uint256 quantity = 10 ether;
        ERC20Core core = erc20;
        core.mint(claimerAddress, quantity, "");

        address to = address(0x121212);
        vm.prank(claimer);

        vm.resumeGasMetering();

        // Transfer token
        core.transfer(to, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        address newImpl = address(new MockHookERC20());
        address proxyAdmin = platformAdmin;
        MockHookERC20 proxy = MockHookERC20(payable(hookProxyAddress));

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

        IHook mockHook = IHook(address(new MockOneHookImplERC20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(hookProxyAddress);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(address(mockHook), 0, ""));
    }

    function test_installFourHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImplERC20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(hookProxyAddress);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(address(mockHook), 0, ""));
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImplERC20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(address(mockHook));
    }

    function test_uninstallFourHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImplERC20()));
        ERC20Core hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(hookProxyAddress);

        vm.prank(platformUser);
        hookConsumer.installHook(IHookInstaller.InstallHookParams(address(mockHook), 0, ""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(address(mockHook));
    }
}
