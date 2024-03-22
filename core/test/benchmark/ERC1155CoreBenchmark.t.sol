// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IHook} from "src/interface/IHook.sol";
import {IHookInstaller} from "src/interface/IHookInstaller.sol";
import {HookFlagsDirectory} from "src/hook/HookFlagsDirectory.sol";

import {MockHookERC1155, MockOneHookImpl, MockFourHookImpl} from "test/mocks/MockHook.sol";

import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

contract ERC1155CoreBenchmarkTest is Test, HookFlagsDirectory {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC1155Core public erc1155;
    address public hookProxyAddress;

    function setUp() public {
        // Setup: minting on ERC-1155 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        hookProxyAddress = address(
            new EIP1967Proxy(
                address(new MockHookERC1155()),
                abi.encodeWithSelector(
                    MockHookERC1155.initialize.selector,
                    platformAdmin // upgradeAdmin
                )
            )
        );

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        ERC1155Core.OnInitializeParams memory onInitializeCall;
        ERC1155Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc1155 = new ERC1155Core(
            "Test ERC1155",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        // Developer installs `MockHookERC1155` hook
        erc1155.installHook(IHookInstaller.InstallHookParams(IHook(hookProxyAddress), 0, bytes("")));

        vm.stopPrank();

        vm.label(address(erc1155), "ERC1155Core");
        vm.label(hookProxyAddress, "MockHookERC1155");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC1155Core implementation contract.

        vm.pauseGasMetering();

        ERC1155Core.OnInitializeParams memory onInitializeCall;
        ERC1155Core.InstallHookParams[] memory hooksToInstallOnInit;

        vm.resumeGasMetering();

        ERC1155Core core = new ERC1155Core(
            "Test ERC1155",
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
        uint256 tokenId = 0;

        ERC1155Core core = erc1155;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, tokenId, quantity, "");
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state

        address claimerAddress = claimer;
        uint256 quantity = 10;
        uint256 tokenId = 0;

        ERC1155Core core = erc1155;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, tokenId, quantity, "");
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state

        address claimerAddress = claimer;
        uint256 quantity = 10;
        uint256 tokenId = 0;

        ERC1155Core core = erc1155;

        core.mint(claimerAddress, tokenId, quantity, "");

        address to = address(0x121212);
        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Transfer token
        core.safeTransferFrom(claimerAddress, to, tokenId, 1, "");
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade() public {
        vm.pauseGasMetering();

        address newImpl = address(new MockHookERC1155());
        address proxyAdmin = platformAdmin;
        MockHookERC1155 proxy = MockHookERC1155(payable(hookProxyAddress));

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
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        erc1155.uninstallHook(BEFORE_MINT_ERC20_FLAG);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_installFoueHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        erc1155.uninstallHook(BEFORE_MINT_ERC20_FLAG);

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockOneHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(BEFORE_MINT_ERC20_FLAG);
    }

    function test_uninstallFourHooks() public {
        vm.pauseGasMetering();

        IHook mockHook = IHook(address(new MockFourHookImpl()));
        ERC1155Core hookConsumer = erc1155;

        vm.prank(platformUser);
        hookConsumer.uninstallHook(BEFORE_MINT_ERC20_FLAG);

        vm.prank(platformUser);
        hookConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, ""));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallHook(
            BEFORE_MINT_ERC20_FLAG | BEFORE_TRANSFER_ERC20_FLAG | BEFORE_BURN_ERC20_FLAG | BEFORE_APPROVE_ERC20_FLAG
        );
    }
}
