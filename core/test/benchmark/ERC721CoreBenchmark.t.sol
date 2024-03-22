// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IHook} from "src/interface/IHook.sol";
import {IHookInstaller} from "src/interface/IHookInstaller.sol";
import {HookFlagsDirectory} from "src/hook/HookFlagsDirectory.sol";

import {MockHookERC721, MockOneHookImplERC721, MockFourHookImplERC721} from "test/mocks/MockHook.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";

contract ERC721CoreBenchmarkTest is Test, HookFlagsDirectory {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721;
    address public hookProxyAddress;

    function setUp() public {
        // Setup: minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        hookProxyAddress = address(
            new EIP1967Proxy(
                address(new MockHookERC721()),
                abi.encodeWithSelector(
                    MockHookERC721.initialize.selector,
                    platformAdmin // upgradeAdmin
                )
            )
        );

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc721 = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        // Developer installs `MockHookERC721` hook
        erc721.installHook(IHookInstaller.InstallHookParams(IHook(hookProxyAddress), 0, bytes("")));

        vm.stopPrank();

        vm.label(address(erc721), "ERC721Core");
        vm.label(hookProxyAddress, "MockHookERC721");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit;

        vm.resumeGasMetering();

        ERC721Core core = new ERC721Core(
            "Test ERC721",
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
        uint256 quantity = 1;
        ERC721Core core = erc721;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, quantity, "");
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state

        address claimerAddress = claimer;
        uint256 quantity = 10;
        ERC721Core core = erc721;

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
        uint256 quantity = 10;
        ERC721Core core = erc721;

        core.mint(claimerAddress, quantity, "");

        address to = address(0x121212);
        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Transfer token
        core.transferFrom(claimerAddress, to, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        address newImpl = address(new MockHookERC721());
        address proxyAdmin = platformAdmin;
        MockHookERC721 proxy = MockHookERC721(payable(hookProxyAddress));

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

        IHook mockHook = IHook(address(new MockOneHookImplERC721()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        erc721.uninstallHook(BEFORE_MINT_ERC721_FLAG);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImplERC721()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(BEFORE_MINT_ERC721_FLAG);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImplERC721()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(BEFORE_MINT_ERC721_FLAG);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImplERC721()));
        ERC721Core hookConsumer = erc721;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(BEFORE_MINT_ERC721_FLAG);

        vm.prank(platformUser);
        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(
            BEFORE_MINT_ERC721_FLAG | BEFORE_TRANSFER_ERC721_FLAG | BEFORE_BURN_ERC721_FLAG | BEFORE_APPROVE_ERC721_FLAG
        );
    }
}
