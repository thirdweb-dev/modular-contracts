// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";

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

    address public mintHookERC20Proxy;
    address public mintHookERC721Proxy;
    address public mintHookERC1155Proxy;

    BuggyAllowlistMintHookERC20 public buggyMintHookERC20Impl;
    BuggyAllowlistMintHookERC721 public buggyMintHookERC721Impl;
    BuggyAllowlistMintHookERC1155 public buggyMintHookERC1155Impl;

    AllowlistMintHookERC20 public mintHookERC20Impl;
    AllowlistMintHookERC721 public mintHookERC721Impl;
    AllowlistMintHookERC1155 public mintHookERC1155Impl;

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

        mintHookERC20Impl = new AllowlistMintHookERC20();
        mintHookERC721Impl = new AllowlistMintHookERC721();
        mintHookERC1155Impl = new AllowlistMintHookERC1155();

        // Platform deploys proxy pointing to hooks. Starts out with using buggy hooks.
        bytes memory hookInitData = abi.encodeWithSelector(
            AllowlistMintHookERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        mintHookERC20Proxy = address(new EIP1967Proxy(address(buggyMintHookERC20Impl), hookInitData));
        mintHookERC721Proxy = address(new EIP1967Proxy(address(buggyMintHookERC721Impl), hookInitData));
        mintHookERC1155Proxy = address(new EIP1967Proxy(address(buggyMintHookERC1155Impl), hookInitData));

        // Deploy core contracts
        CloneFactory cloneFactory = new CloneFactory();

        ERC20Core.InitCall memory initCall;
        bytes memory initData = abi.encodeWithSelector(
            ERC20Core.initialize.selector,
            initCall,
            new address[](0),
            developer, // core contract admin
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0"
        );

        address erc20CoreImpl = address(new ERC20Core());
        address erc721CoreImpl = address(new ERC721Core());
        address erc1155CoreImpl = address(new ERC1155Core());

        erc20Core = ERC20Core(cloneFactory.deployProxyByImplementation(erc20CoreImpl, initData, bytes32("salt")));
        erc721Core = ERC721Core(cloneFactory.deployProxyByImplementation(erc721CoreImpl, initData, bytes32("salt")));
        erc1155Core = ERC1155Core(cloneFactory.deployProxyByImplementation(erc1155CoreImpl, initData, bytes32("salt")));

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");

        vm.label(address(erc20Core), "ERC20Core");
        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(erc1155Core), "ERC1155Core");

        vm.label(mintHookERC20Proxy, "ProxyMintHookERC20");
        vm.label(mintHookERC721Proxy, "ProxyMintHookERC721");
        vm.label(mintHookERC1155Proxy, "ProxyMintHookERC1155");

        vm.label(address(buggyMintHookERC20Impl), "BuggyMintHookERC20");
        vm.label(address(buggyMintHookERC721Impl), "BuggyMintHookERC721");
        vm.label(address(buggyMintHookERC1155Impl), "BuggyMintHookERC1155");

        vm.label(address(mintHookERC20Impl), "AllowlistMintHookERC20");
        vm.label(address(mintHookERC721Impl), "AllowlistMintHookERC721");
        vm.label(address(mintHookERC1155Impl), "AllowlistMintHookERC1155");

        // Developer installs hooks.
        vm.startPrank(developer);

        erc20Core.installHook(IHook(mintHookERC20Proxy));
        erc721Core.installHook(IHook(mintHookERC721Proxy));
        erc1155Core.installHook(IHook(mintHookERC1155Proxy));

        vm.stopPrank();

        // Developer sets claim conditions; non-zero price

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

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

        vm.startPrank(developer);
        AllowlistMintHookERC20(mintHookERC20Proxy).setClaimCondition(address(erc20Core), conditionERC20);
        AllowlistMintHookERC721(mintHookERC721Proxy).setClaimCondition(address(erc721Core), conditionERC721);
        AllowlistMintHookERC1155(mintHookERC1155Proxy).setClaimCondition(address(erc1155Core), 0, conditionERC1155);
        vm.stopPrank();

        // Developer sets fee config; sets self as primary sale recipient
        AllowlistMintHookERC20.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = developer;

        vm.startPrank(developer);
        AllowlistMintHookERC20(mintHookERC20Proxy).setDefaultFeeConfig(address(erc20Core), feeConfig);
        AllowlistMintHookERC721(mintHookERC721Proxy).setDefaultFeeConfig(address(erc721Core), feeConfig);
        AllowlistMintHookERC1155(mintHookERC1155Proxy).setDefaultFeeConfig(address(erc1155Core), feeConfig);
        vm.stopPrank();

        // Set minting params
        string[] memory inputsProof = new string[](2);
        inputsProof[0] = "node";
        inputsProof[1] = "test/scripts/getProof.ts";

        bytes memory resultProof = vm.ffi(inputsProof);
        bytes32[] memory allowlistProof = abi.decode(resultProof, (bytes32[]));

        encodedAllowlistProof = abi.encode(allowlistProof);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_upgrade_erc20Core() public {
        assertEq(erc20Core.getAllHooks().beforeMint, mintHookERC20Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(AllowlistMintHookERC20(mintHookERC20Proxy).getClaimCondition(address(erc20Core)).price, pricePerToken);

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintHookERC20Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(mintHookERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC20Hook.ERC20UnauthorizedUpgrade.selector));
        AllowlistMintHookERC20(mintHookERC20Proxy).upgradeToAndCall(address(mintHookERC20Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC20(mintHookERC20Proxy).upgradeToAndCall(address(mintHookERC20Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        assertEq(mintHookERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc721Core() public {
        assertEq(erc721Core.getAllHooks().beforeMint, mintHookERC721Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintHookERC721(mintHookERC721Proxy).getClaimCondition(address(erc721Core)).price, pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintHookERC721Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(mintHookERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC721Hook.ERC721UnauthorizedUpgrade.selector));
        AllowlistMintHookERC721(mintHookERC721Proxy).upgradeToAndCall(address(mintHookERC721Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC721(mintHookERC721Proxy).upgradeToAndCall(address(mintHookERC721Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        assertEq(mintHookERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc1155Core() public {
        uint256 tokenId = 0;

        assertEq(erc1155Core.getAllHooks().beforeMint, mintHookERC1155Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintHookERC1155(mintHookERC1155Proxy).getClaimCondition(address(erc1155Core), tokenId).price,
            pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintHookERC1155Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in hook contract.
        assertEq(mintHookERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades hook implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC1155Hook.ERC1155UnauthorizedUpgrade.selector));
        AllowlistMintHookERC1155(mintHookERC1155Proxy).upgradeToAndCall(address(mintHookERC1155Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintHookERC1155(mintHookERC1155Proxy).upgradeToAndCall(address(mintHookERC1155Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        assertEq(mintHookERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }
}
