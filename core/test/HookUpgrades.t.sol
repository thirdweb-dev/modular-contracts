// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";
import {IHookInstaller} from "src/interface/hook/IHookInstaller.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {
    MockHookERC20,
    BuggyMockHookERC20,
    MockHookERC721,
    BuggyMockHookERC721,
    MockHookERC1155,
    BuggyMockHookERC1155
} from "test/mocks/MockHook.sol";

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

    address public hookERC20Proxy;
    address public hookERC721Proxy;
    address public hookERC1155Proxy;

    BuggyMockHookERC20 public buggyHookERC20Impl;
    BuggyMockHookERC721 public buggyHookERC721Impl;
    BuggyMockHookERC1155 public buggyHookERC1155Impl;

    MockHookERC20 public hookERC20Impl;
    MockHookERC721 public hookERC721Impl;
    MockHookERC1155 public hookERC1155Impl;

    function setUp() public {
        // Platform deploys hook implementations
        buggyHookERC20Impl = new BuggyMockHookERC20();
        buggyHookERC721Impl = new BuggyMockHookERC721();
        buggyHookERC1155Impl = new BuggyMockHookERC1155();

        hookERC20Impl = new MockHookERC20();
        hookERC721Impl = new MockHookERC721();
        hookERC1155Impl = new MockHookERC1155();

        // Platform deploys proxy pointing to hooks. Starts out with using buggy hooks.
        bytes memory hookInitData = abi.encodeWithSelector(
            MockHookERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        hookERC20Proxy = address(new EIP1967Proxy(address(buggyHookERC20Impl), hookInitData));
        hookERC721Proxy = address(new EIP1967Proxy(address(buggyHookERC721Impl), hookInitData));
        hookERC1155Proxy = address(new EIP1967Proxy(address(buggyHookERC1155Impl), hookInitData));

        // Deploy core contracts
        ERC20Core.OnInitializeParams memory onInitializeCall;
        ERC20Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc20Core = new ERC20Core(
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );
        erc721Core = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            developer, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
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

        vm.label(hookERC20Proxy, "ProxyMintHookERC20");
        vm.label(hookERC721Proxy, "ProxyMintHookERC721");
        vm.label(hookERC1155Proxy, "ProxyMintHookERC1155");

        vm.label(address(buggyHookERC20Impl), "BuggyMintHookERC20");
        vm.label(address(buggyHookERC721Impl), "BuggyMintHookERC721");
        vm.label(address(buggyHookERC1155Impl), "BuggyMintHookERC1155");

        vm.label(address(hookERC20Impl), "MockHookERC20");
        vm.label(address(hookERC721Impl), "MockHookERC721");
        vm.label(address(hookERC1155Impl), "MockHookERC1155");

        // Developer installs hooks.
        vm.startPrank(developer);

        erc20Core.installHook(IHookInstaller.InstallHookParams(IHook(hookERC20Proxy), 0, bytes("")));
        erc721Core.installHook(IHookInstaller.InstallHookParams(IHook(hookERC721Proxy), 0, bytes("")));
        erc1155Core.installHook(IHookInstaller.InstallHookParams(IHook(hookERC1155Proxy), 0, bytes("")));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_upgrade_erc20Core() public {
        assertEq(erc20Core.getAllHooks().beforeMint, hookERC20Proxy);

        // End user specifies 1 ether token to claim
        assertEq(erc20Core.balanceOf(endUser), 0);

        vm.prank(endUser);
        vm.expectRevert();
        erc20Core.mint(endUser, 1 ether, "");

        // BUG: zero tokens minted in all cases!
        assertEq(erc20Core.balanceOf(endUser), 0);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(MockHookERC20.UnauthorizedUpgrade.selector));
        MockHookERC20(hookERC20Proxy).upgradeToAndCall(address(hookERC20Impl), bytes(""));

        vm.prank(platformAdmin);
        MockHookERC20(hookERC20Proxy).upgradeToAndCall(address(hookERC20Impl), bytes(""));

        // Claim token again; this time contract mints specified quantity.
        assertEq(erc20Core.balanceOf(endUser), 0);

        vm.prank(endUser);
        erc20Core.mint(endUser, 1 ether, "");

        assertEq(erc20Core.balanceOf(endUser), 1 ether);
    }

    function test_upgrade_erc721Core() public {
        assertEq(erc721Core.getAllHooks().beforeMint, hookERC721Proxy);

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
        vm.expectRevert(abi.encodeWithSelector(MockHookERC20.UnauthorizedUpgrade.selector));
        MockHookERC721(hookERC721Proxy).upgradeToAndCall(address(hookERC721Impl), bytes(""));

        vm.prank(platformAdmin);
        MockHookERC721(hookERC721Proxy).upgradeToAndCall(address(hookERC721Impl), bytes(""));

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
        vm.expectRevert(abi.encodeWithSelector(MockHookERC20.UnauthorizedUpgrade.selector));
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
