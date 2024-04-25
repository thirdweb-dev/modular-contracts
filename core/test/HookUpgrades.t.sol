// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IHook} from "src/interface/IHook.sol";
import {IHookInstaller} from "src/interface/IHookInstaller.sol";
import {ICoreContract} from "src/interface/ICoreContract.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {MockHookERC1155, BuggyMockHookERC1155} from "test/mocks/MockHook.sol";
import {
    MockExtensionERC20,
    BuggyMockExtensionERC20,
    MockExtensionERC721,
    BuggyMockExtensionERC721
} from "test/mocks/MockExtension.sol";

contract HookUpgradesTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC20Core public erc20Core;
    ERC721Core public erc721Core;
    ERC1155Core public erc1155Core;

    address public extensionERC20Proxy;
    address public extensionERC721Proxy;
    address public hookERC1155Proxy;

    BuggyMockExtensionERC20 public buggyExtensionERC20Impl;
    BuggyMockExtensionERC721 public buggyExtensionERC721Impl;
    BuggyMockHookERC1155 public buggyHookERC1155Impl;

    MockExtensionERC20 public extensionERC20Impl;
    MockExtensionERC721 public extensionERC721Impl;
    MockHookERC1155 public hookERC1155Impl;

    function setUp() public {
        // Platform deploys hook implementations
        buggyExtensionERC20Impl = new BuggyMockExtensionERC20();
        buggyExtensionERC721Impl = new BuggyMockExtensionERC721();
        buggyHookERC1155Impl = new BuggyMockHookERC1155();

        extensionERC20Impl = new MockExtensionERC20();
        extensionERC721Impl = new MockExtensionERC721();
        hookERC1155Impl = new MockHookERC1155();

        // Platform deploys proxy pointing to hooks. Starts out with using buggy hooks.
        bytes memory hookInitData = abi.encodeWithSelector(
            MockExtensionERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        extensionERC20Proxy = address(new EIP1967Proxy(address(buggyExtensionERC20Impl), hookInitData));
        extensionERC721Proxy = address(new EIP1967Proxy(address(buggyExtensionERC721Impl), hookInitData));
        hookERC1155Proxy = address(new EIP1967Proxy(address(buggyHookERC1155Impl), hookInitData));

        // Deploy core contracts
        ERC1155Core.OnInitializeParams memory onInitializeCall;
        ERC1155Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc20Core = new ERC20Core(
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner
            new address[](0),
            address(0),
            bytes("")
        );
        erc721Core = new ERC721Core(
            "Token",
            "TKN",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner,
            new address[](0),
            address(0),
            bytes("")
        );
        erc1155Core = new ERC1155Core(
            "Test ERC1155",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");

        vm.label(address(erc20Core), "ERC20Core");
        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(erc1155Core), "ERC1155Core");

        vm.label(extensionERC20Proxy, "ProxyMintHookERC20");
        vm.label(extensionERC721Proxy, "ProxyMintHookERC721");
        vm.label(hookERC1155Proxy, "ProxyMintHookERC1155");

        vm.label(address(buggyExtensionERC20Impl), "BuggyMintHookERC20");
        vm.label(address(buggyExtensionERC721Impl), "BuggyMintHookERC721");
        vm.label(address(buggyHookERC1155Impl), "BuggyMintHookERC1155");

        vm.label(address(extensionERC20Impl), "MockExtensionERC20");
        vm.label(address(extensionERC721Impl), "MockExtensionERC721");
        vm.label(address(hookERC1155Impl), "MockHookERC1155");

        // Developer installs hooks.
        vm.startPrank(developer);

        erc20Core.installExtension(address(extensionERC20Proxy), 0, "");
        erc721Core.installExtension(address(extensionERC721Proxy), 0, "");
        erc1155Core.installHook(IHookInstaller.InstallHookParams(hookERC1155Proxy, 0, bytes("")));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_upgrade_erc20Core() public {
        ICoreContract.InstalledExtension[] memory installedExtensions = erc20Core.getInstalledExtensions();
        assertEq(installedExtensions.length, 1);
        assertEq(installedExtensions[0].implementation, extensionERC20Proxy);

        // End user specifies 1 ether token to claim
        assertEq(erc20Core.balanceOf(endUser), 0);

        vm.prank(endUser);
        vm.expectRevert();
        erc20Core.mint(endUser, 1 ether, "");

        // BUG: zero tokens minted in all cases!
        assertEq(erc20Core.balanceOf(endUser), 0);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(MockExtensionERC20.UnauthorizedUpgrade.selector));
        MockExtensionERC20(extensionERC20Proxy).upgradeToAndCall(address(extensionERC20Impl), bytes(""));

        vm.prank(platformAdmin);
        MockExtensionERC20(extensionERC20Proxy).upgradeToAndCall(address(extensionERC20Impl), bytes(""));

        // Claim token again; this time contract mints specified quantity.
        assertEq(erc20Core.balanceOf(endUser), 0);

        vm.prank(endUser);
        erc20Core.mint(endUser, 1 ether, "");

        assertEq(erc20Core.balanceOf(endUser), 1 ether);
    }

    function test_upgrade_erc721Core() public {
        ICoreContract.InstalledExtension[] memory installedExtensions = erc721Core.getInstalledExtensions();
        assertEq(installedExtensions.length, 1);
        assertEq(installedExtensions[0].implementation, extensionERC721Proxy);

        // End user specifies 1 token to claim
        assertEq(erc721Core.balanceOf(endUser), 0);
        vm.expectRevert();
        erc721Core.ownerOf(0);

        vm.prank(endUser);
        vm.expectRevert();
        erc721Core.mint(endUser, 1, "");

        // BUG: zero tokens minted in all cases!
        assertEq(erc721Core.balanceOf(endUser), 0);
        vm.expectRevert();
        erc721Core.ownerOf(0);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(MockExtensionERC20.UnauthorizedUpgrade.selector));
        MockExtensionERC721(extensionERC721Proxy).upgradeToAndCall(address(extensionERC721Impl), bytes(""));

        vm.prank(platformAdmin);
        MockExtensionERC721(extensionERC721Proxy).upgradeToAndCall(address(extensionERC721Impl), bytes(""));

        // Claim token again; this time contract mints specified quantity.
        assertEq(erc721Core.balanceOf(endUser), 0);

        vm.prank(endUser);
        erc721Core.mint(endUser, 1, "");

        assertEq(erc721Core.balanceOf(endUser), 1);
        assertEq(erc721Core.ownerOf(0), endUser);
    }

    function test_upgrade_erc1155Core() public {
        assertEq(erc1155Core.getAllHooks().beforeMint, hookERC1155Proxy);

        // End user specifies 1 token to claim
        assertEq(erc1155Core.balanceOf(endUser, 0), 0);

        vm.prank(endUser);
        vm.expectRevert();
        erc1155Core.mint(endUser, 0, 1, "");

        // BUG: zero tokens minted in all cases!
        assertEq(erc1155Core.balanceOf(endUser, 0), 0);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(MockExtensionERC20.UnauthorizedUpgrade.selector));
        MockHookERC1155(hookERC1155Proxy).upgradeToAndCall(address(hookERC1155Impl), bytes(""));

        vm.prank(platformAdmin);
        MockHookERC1155(hookERC1155Proxy).upgradeToAndCall(address(hookERC1155Impl), bytes(""));

        // Claim token again; this time contract mints specified quantity.
        assertEq(erc1155Core.balanceOf(endUser, 0), 0);

        vm.prank(endUser);
        erc1155Core.mint(endUser, 0, 1, "");

        assertEq(erc1155Core.balanceOf(endUser, 0), 1);
    }
}
