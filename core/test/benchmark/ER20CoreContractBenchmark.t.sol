// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IExtensionContract} from "src/interface/IExtensionContract.sol";
import {CoreContract, ICoreContract} from "src/core/CoreContract.sol";

import {
    MockExtensionERC20,
    MockExtensionWithOneCallbackERC20,
    MockExtensionWithFourCallbacksERC20
} from "test/mocks/MockExtension.sol";

import {ERC20CoreContract} from "src/core/token/ERC20CoreContract.sol";

contract ERC20CoreContractBenchmarkTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC20CoreContract public erc20;
    address public hookProxyAddress;

    function setUp() public {
        // Setup: minting on ERC-20 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        hookProxyAddress = address(
            new EIP1967Proxy(
                address(new MockExtensionERC20()),
                abi.encodeWithSelector(
                    MockExtensionERC20.initialize.selector,
                    platformAdmin // upgradeAdmin
                )
            )
        );

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        address[] memory extensionsToInstall = new address[](0);

        erc20 = new ERC20CoreContract(
            "Token",
            "TKN",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner,
            extensionsToInstall,
            address(0),
            bytes("")
        );

        vm.stopPrank();

        vm.label(address(erc20), "ERC20CoreContract");
        vm.label(hookProxyAddress, "MockExtensionERC20");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC20CoreContract implementation contract.

        vm.pauseGasMetering();

        address[] memory extensionsToInstall = new address[](1);
        extensionsToInstall[0] = hookProxyAddress;

        vm.resumeGasMetering();

        ERC20CoreContract core = new ERC20CoreContract(
            "Token",
            "TKN",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner,
            extensionsToInstall,
            address(0),
            bytes("")
        );
    }

    /*//////////////////////////////////////////////////////////////
                        MINT 1 TOKEN AND 10 TOKENS
    //////////////////////////////////////////////////////////////*/

    function test_mintOneToken() public {
        vm.pauseGasMetering();

        vm.prank(platformUser);
        erc20.installExtension(hookProxyAddress, 0, "");

        // Check pre-mint state
        address claimerAddress = claimer;
        uint256 quantity = 1 ether;
        ERC20CoreContract core = erc20;

        vm.prank(claimer);

        vm.resumeGasMetering();

        // Claim token
        core.mint(claimerAddress, quantity, "");
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        vm.prank(platformUser);
        erc20.installExtension(hookProxyAddress, 0, "");

        // Check pre-mint state
        address claimerAddress = claimer;
        uint256 quantity = 10 ether;
        ERC20CoreContract core = erc20;

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

        vm.prank(platformUser);
        erc20.installExtension(hookProxyAddress, 0, "");

        // Check pre-mint state
        address claimerAddress = claimer;
        uint256 quantity = 10 ether;
        ERC20CoreContract core = erc20;
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

        address newImpl = address(new MockExtensionERC20());
        address proxyAdmin = platformAdmin;
        MockExtensionERC20 proxy = MockExtensionERC20(payable(hookProxyAddress));

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

        address mockHook = address(new MockExtensionWithOneCallbackERC20());
        ERC20CoreContract hookConsumer = erc20;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installExtension(mockHook, 0, "");
    }

    function test_installFourHooks() public {
        vm.pauseGasMetering();

        address mockHook = address(new MockExtensionWithFourCallbacksERC20());
        ERC20CoreContract hookConsumer = erc20;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.installExtension(mockHook, 0, "");
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        ERC20CoreContract hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.installExtension(hookProxyAddress, 0, "");

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallExtension(hookProxyAddress, 0, "");
    }

    function test_uninstallFourHooks() public {
        vm.pauseGasMetering();

        address mockHook = address(new MockExtensionWithFourCallbacksERC20());
        ERC20CoreContract hookConsumer = erc20;

        vm.prank(platformUser);
        hookConsumer.installExtension(mockHook, 0, "");

        vm.prank(platformUser);

        vm.resumeGasMetering();

        hookConsumer.uninstallExtension(mockHook, 0, "");
    }
}
