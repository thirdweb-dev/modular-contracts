// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IExtension} from "src/interface/extension/IExtension.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {AllowlistMintExtensionERC20, ERC20Extension} from "src/extension/mint/AllowlistMintExtensionERC20.sol";
import {AllowlistMintExtensionERC721, ERC721Extension} from "src/extension/mint/AllowlistMintExtensionERC721.sol";
import {AllowlistMintExtensionERC1155, ERC1155Extension} from "src/extension/mint/AllowlistMintExtensionERC1155.sol";

import {
    BuggyAllowlistMintExtensionERC20,
    BuggyAllowlistMintExtensionERC721,
    BuggyAllowlistMintExtensionERC1155
} from "test/mocks/BuggyAllowlistMintExtension.sol";

contract ExtensionUpgradesTest is Test {
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

    address public mintExtensionERC20Proxy;
    address public mintExtensionERC721Proxy;
    address public mintExtensionERC1155Proxy;

    BuggyAllowlistMintExtensionERC20 public buggyMintExtensionERC20Impl;
    BuggyAllowlistMintExtensionERC721 public buggyMintExtensionERC721Impl;
    BuggyAllowlistMintExtensionERC1155 public buggyMintExtensionERC1155Impl;

    AllowlistMintExtensionERC20 public MintExtensionERC20Impl;
    AllowlistMintExtensionERC721 public MintExtensionERC721Impl;
    AllowlistMintExtensionERC1155 public MintExtensionERC1155Impl;

    // Token claim params
    uint256 public pricePerToken = 1 ether;
    uint256 public availableSupply = 100 ether;

    // Minting params
    bytes public encodedAllowlistProof;

    function setUp() public {
        // Platform deploys extension implementations
        buggyMintExtensionERC20Impl = new BuggyAllowlistMintExtensionERC20();
        buggyMintExtensionERC721Impl = new BuggyAllowlistMintExtensionERC721();
        buggyMintExtensionERC1155Impl = new BuggyAllowlistMintExtensionERC1155();

        MintExtensionERC20Impl = new AllowlistMintExtensionERC20();
        MintExtensionERC721Impl = new AllowlistMintExtensionERC721();
        MintExtensionERC1155Impl = new AllowlistMintExtensionERC1155();

        // Platform deploys proxy pointing to extensions. Starts out with using buggy extensions.
        bytes memory extensionInitData = abi.encodeWithSelector(
            AllowlistMintExtensionERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        mintExtensionERC20Proxy = address(new EIP1967Proxy(address(buggyMintExtensionERC20Impl), extensionInitData));
        mintExtensionERC721Proxy = address(new EIP1967Proxy(address(buggyMintExtensionERC721Impl), extensionInitData));
        mintExtensionERC1155Proxy = address(new EIP1967Proxy(address(buggyMintExtensionERC1155Impl), extensionInitData));

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

        vm.label(mintExtensionERC20Proxy, "ProxyMintExtensionERC20");
        vm.label(mintExtensionERC721Proxy, "ProxyMintExtensionERC721");
        vm.label(mintExtensionERC1155Proxy, "ProxyMintExtensionERC1155");

        vm.label(address(buggyMintExtensionERC20Impl), "BuggyMintExtensionERC20");
        vm.label(address(buggyMintExtensionERC721Impl), "BuggyMintExtensionERC721");
        vm.label(address(buggyMintExtensionERC1155Impl), "BuggyMintExtensionERC1155");

        vm.label(address(MintExtensionERC20Impl), "AllowlistMintExtensionERC20");
        vm.label(address(MintExtensionERC721Impl), "AllowlistMintExtensionERC721");
        vm.label(address(MintExtensionERC1155Impl), "AllowlistMintExtensionERC1155");

        // Developer installs extensions.
        vm.startPrank(developer);

        erc20Core.installExtension(IExtension(mintExtensionERC20Proxy));
        erc721Core.installExtension(IExtension(mintExtensionERC721Proxy));
        erc1155Core.installExtension(IExtension(mintExtensionERC1155Proxy));

        vm.stopPrank();

        // Developer sets claim conditions; non-zero price

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";

        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

        AllowlistMintExtensionERC20.ClaimCondition memory conditionERC20 = AllowlistMintExtensionERC20.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });
        AllowlistMintExtensionERC721.ClaimCondition memory conditionERC721 = AllowlistMintExtensionERC721.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });
        AllowlistMintExtensionERC1155.ClaimCondition memory conditionERC1155 = AllowlistMintExtensionERC1155.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        vm.startPrank(developer);
        erc20Core.hookFunctionWrite(erc20Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC20.setClaimCondition.selector, conditionERC20));
        erc721Core.hookFunctionWrite(erc721Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC721.setClaimCondition.selector, conditionERC721));
        erc1155Core.hookFunctionWrite(erc1155Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, conditionERC1155));
        vm.stopPrank();

        // Developer sets fee config; sets self as primary sale recipient
        AllowlistMintExtensionERC20.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = developer;

        vm.startPrank(developer);
        erc20Core.hookFunctionWrite(erc20Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC20.setDefaultFeeConfig.selector, feeConfig));
        erc721Core.hookFunctionWrite(erc721Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        erc1155Core.hookFunctionWrite(erc1155Core.BEFORE_MINT_FLAG(), 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setDefaultFeeConfig.selector, feeConfig));
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
        assertEq(erc20Core.getAllExtensions().beforeMint, mintExtensionERC20Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(AllowlistMintExtensionERC20(mintExtensionERC20Proxy).getClaimCondition(address(erc20Core)).price, pricePerToken);

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintExtensionERC20Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in extension contract.
        assertEq(mintExtensionERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades extension implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC20Extension.ERC20UnauthorizedUpgrade.selector));
        AllowlistMintExtensionERC20(mintExtensionERC20Proxy).upgradeToAndCall(address(MintExtensionERC20Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintExtensionERC20(mintExtensionERC20Proxy).upgradeToAndCall(address(MintExtensionERC20Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc20Core.mint{value: pricePerToken}(endUser, 1 ether, encodedAllowlistProof);

        assertEq(mintExtensionERC20Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc721Core() public {
        assertEq(erc721Core.getAllExtensions().beforeMint, mintExtensionERC721Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintExtensionERC721(mintExtensionERC721Proxy).getClaimCondition(address(erc721Core)).price, pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintExtensionERC721Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in extension contract.
        assertEq(mintExtensionERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades extension implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC721Extension.ERC721UnauthorizedUpgrade.selector));
        AllowlistMintExtensionERC721(mintExtensionERC721Proxy).upgradeToAndCall(address(MintExtensionERC721Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintExtensionERC721(mintExtensionERC721Proxy).upgradeToAndCall(address(MintExtensionERC721Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc721Core.mint{value: pricePerToken}(endUser, 1, encodedAllowlistProof);

        assertEq(mintExtensionERC721Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }

    function test_upgrade_erc1155Core() public {
        uint256 tokenId = 0;

        assertEq(erc1155Core.getAllExtensions().beforeMint, mintExtensionERC1155Proxy);
        assertTrue(pricePerToken > 0);
        assertEq(
            AllowlistMintExtensionERC1155(mintExtensionERC1155Proxy).getClaimCondition(address(erc1155Core), tokenId).price,
            pricePerToken
        );

        // End user claims token: BUG: pays price but contract fails to distribute it!

        // Claim token

        assertEq(mintExtensionERC1155Proxy.balance, 0);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether);

        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        // BUG: Contract fails to distribute price to primary sale recipient.
        //      Money stuck in extension contract.
        assertEq(mintExtensionERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, 0);
        assertEq(endUser.balance, 100 ether - pricePerToken);

        // Platform upgrades extension implementation to fix this bug.
        vm.prank(address(0x324254));
        vm.expectRevert(abi.encodeWithSelector(ERC1155Extension.ERC1155UnauthorizedUpgrade.selector));
        AllowlistMintExtensionERC1155(mintExtensionERC1155Proxy).upgradeToAndCall(address(MintExtensionERC1155Impl), bytes(""));

        vm.prank(platformAdmin);
        AllowlistMintExtensionERC1155(mintExtensionERC1155Proxy).upgradeToAndCall(address(MintExtensionERC1155Impl), bytes(""));

        // Claim token again; this time sale value gets distributed to primary sale recipient.
        vm.prank(endUser);
        erc1155Core.mint{value: pricePerToken}(endUser, tokenId, 1, encodedAllowlistProof);

        assertEq(mintExtensionERC1155Proxy.balance, pricePerToken);
        assertEq(developer.balance, pricePerToken);
        assertEq(endUser.balance, 100 ether - (pricePerToken * 2));
    }
}
