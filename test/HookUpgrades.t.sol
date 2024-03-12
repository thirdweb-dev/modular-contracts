// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "@murky/Merkle.sol";

import {Multicallable} from "@solady/utils/Multicallable.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";
import {IHookInstaller} from "src/interface/hook/IHookInstaller.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {AllowlistMintHookERC20, ERC20Hook} from "src/hook/mint/AllowlistMintHookERC20.sol";
import {AllowlistMintHookERC721, ERC721Hook} from "src/hook/mint/AllowlistMintHookERC721.sol";
import {AllowlistMintHookERC1155, ERC1155Hook} from "src/hook/mint/AllowlistMintHookERC1155.sol";

import {
    BuggyAllowlistMintHookERC20,
    BuggyAllowlistMintHookERC721,
    BuggyAllowlistMintHookERC1155
} from "test/mocks/BuggyAllowlistMintHook.sol";

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

    address public MintHookERC20Proxy;
    address public MintHookERC721Proxy;
    address public MintHookERC1155Proxy;

    BuggyAllowlistMintHookERC20 public buggyMintHookERC20Impl;
    BuggyAllowlistMintHookERC721 public buggyMintHookERC721Impl;
    BuggyAllowlistMintHookERC1155 public buggyMintHookERC1155Impl;

    AllowlistMintHookERC20 public MintHookERC20Impl;
    AllowlistMintHookERC721 public MintHookERC721Impl;
    AllowlistMintHookERC1155 public MintHookERC1155Impl;

    // Token claim params
    uint256 public pricePerToken = 1 ether;
    uint256 public availableSupply = 100 ether;

    // Minting params
    bytes public encodedAllowlistProof;

    function setUp() public {
        // Platform deploys hook implementations
        buggyMintHookERC20Impl = new BuggyAllowlistMintHookERC20();
        buggyMintHookERC721Impl = new BuggyAllowlistMintHookERC721();
        buggyMintHookERC1155Impl = new BuggyAllowlistMintHookERC1155();

        MintHookERC20Impl = new AllowlistMintHookERC20();
        MintHookERC721Impl = new AllowlistMintHookERC721();
        MintHookERC1155Impl = new AllowlistMintHookERC1155();

        // Platform deploys proxy pointing to hooks. Starts out with using buggy hooks.
        bytes memory hookInitData = abi.encodeWithSelector(
            AllowlistMintHookERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        MintHookERC20Proxy = address(new EIP1967Proxy(address(buggyMintHookERC20Impl), hookInitData));
        MintHookERC721Proxy = address(new EIP1967Proxy(address(buggyMintHookERC721Impl), hookInitData));
        MintHookERC1155Proxy = address(new EIP1967Proxy(address(buggyMintHookERC1155Impl), hookInitData));

        // Deploy core contracts
        CloneFactory cloneFactory = new CloneFactory();

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

        vm.label(MintHookERC20Proxy, "ProxyMintHookERC20");
        vm.label(MintHookERC721Proxy, "ProxyMintHookERC721");
        vm.label(MintHookERC1155Proxy, "ProxyMintHookERC1155");

        vm.label(address(buggyMintHookERC20Impl), "BuggyMintHookERC20");
        vm.label(address(buggyMintHookERC721Impl), "BuggyMintHookERC721");
        vm.label(address(buggyMintHookERC1155Impl), "BuggyMintHookERC1155");

        vm.label(address(MintHookERC20Impl), "AllowlistMintHookERC20");
        vm.label(address(MintHookERC721Impl), "AllowlistMintHookERC721");
        vm.label(address(MintHookERC1155Impl), "AllowlistMintHookERC1155");

        // Developer sets claim conditions; non-zero price
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32 root = merkle.getRoot(data);

        AllowlistMintHookERC20.ClaimCondition memory conditionERC20 = AllowlistMintHookERC20.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });
        AllowlistMintHookERC721.ClaimCondition memory conditionERC721 = AllowlistMintHookERC721.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });
        AllowlistMintHookERC1155.ClaimCondition memory conditionERC1155 = AllowlistMintHookERC1155.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        // Developer sets fee config; sets self as primary sale recipient
        AllowlistMintHookERC20.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = developer;

        bytes[] memory multicallInitializeDataERC20 = new bytes[](2);
        multicallInitializeDataERC20[0] =
            abi.encodeWithSelector(AllowlistMintHookERC20.setClaimCondition.selector, conditionERC20);
        multicallInitializeDataERC20[1] =
            abi.encodeWithSelector(AllowlistMintHookERC20.setDefaultFeeConfig.selector, feeConfig);

        bytes[] memory multicallInitializeDataERC721 = new bytes[](2);
        multicallInitializeDataERC721[0] =
            abi.encodeWithSelector(AllowlistMintHookERC721.setClaimCondition.selector, conditionERC721);
        multicallInitializeDataERC721[1] =
            abi.encodeWithSelector(AllowlistMintHookERC721.setDefaultFeeConfig.selector, feeConfig);

        bytes[] memory multicallInitializeDataERC1155 = new bytes[](2);
        multicallInitializeDataERC1155[0] =
            abi.encodeWithSelector(AllowlistMintHookERC1155.setClaimCondition.selector, 0, conditionERC1155);
        multicallInitializeDataERC1155[1] =
            abi.encodeWithSelector(AllowlistMintHookERC1155.setDefaultFeeConfig.selector, feeConfig);

        // Developer installs hooks.
        vm.startPrank(developer);

        erc20Core.installHook(
            IHookInstaller.InstallHookParams(
                IHook(MintHookERC20Proxy),
                0,
                abi.encodeWithSelector(Multicallable.multicall.selector, multicallInitializeDataERC20)
            )
        );
        erc721Core.installHook(
            IHookInstaller.InstallHookParams(
                IHook(MintHookERC721Proxy),
                0,
                abi.encodeWithSelector(Multicallable.multicall.selector, multicallInitializeDataERC721)
            )
        );
        erc1155Core.installHook(
            IHookInstaller.InstallHookParams(
                IHook(MintHookERC1155Proxy),
                0,
                abi.encodeWithSelector(Multicallable.multicall.selector, multicallInitializeDataERC1155)
            )
        );

        vm.stopPrank();

        // Set minting params
        bytes32[] memory allowlistProof = merkle.getProof(data, 0);

        encodedAllowlistProof = abi.encode(allowlistProof);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_upgrade_erc20Core() public {
        assertEq(erc20Core.getAllHooks().beforeMint, MintHookERC20Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(AllowlistMintHookERC20(MintHookERC20Proxy).getClaimCondition(address(erc20Core)).price, pricePerToken);

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(MintHookERC20Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(MintHookERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC20Hook.ERC20UnauthorizedUpgrade.selector));
        AllowlistMintHookERC20(MintHookERC20Proxy).upgradeToAndCall(address(MintHookERC20Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC20(MintHookERC20Proxy).upgradeToAndCall(address(MintHookERC20Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        assertEq(MintHookERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc721Core() public {
        assertEq(erc721Core.getAllHooks().beforeMint, MintHookERC721Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintHookERC721(MintHookERC721Proxy).getClaimCondition(address(erc721Core)).price, pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(MintHookERC721Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(MintHookERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC721Hook.ERC721UnauthorizedUpgrade.selector));
        AllowlistMintHookERC721(MintHookERC721Proxy).upgradeToAndCall(address(MintHookERC721Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC721(MintHookERC721Proxy).upgradeToAndCall(address(MintHookERC721Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        assertEq(MintHookERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc1155Core() public {
        uint256 tokenId = 0;

        assertEq(erc1155Core.getAllHooks().beforeMint, MintHookERC1155Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintHookERC1155(MintHookERC1155Proxy).getClaimCondition(address(erc1155Core), tokenId).price,
            pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(MintHookERC1155Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(MintHookERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC1155Hook.ERC1155UnauthorizedUpgrade.selector));
        AllowlistMintHookERC1155(MintHookERC1155Proxy).upgradeToAndCall(address(MintHookERC1155Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC1155(MintHookERC1155Proxy).upgradeToAndCall(address(MintHookERC1155Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        assertEq(MintHookERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }
}
