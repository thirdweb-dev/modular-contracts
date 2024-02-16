// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IExtension} from "src/interface/extension/IExtension.sol";

import {ERC1155Core, ExtensionInstaller} from "src/core/token/ERC1155Core.sol";
import {AllowlistMintExtensionERC1155, ERC1155Extension} from "src/extension/mint/AllowlistMintExtensionERC1155.sol";
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol"; 

contract AllowlistMintExtensionERC1155Test is Test {

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);

    uint256 developerPKey = 100;
    address public developer;
    
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC1155Core public erc1155Core;
    AllowlistMintExtensionERC1155 public mintExtension;

    // Test params
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );
    bytes32 public domainSeparator;
    
    bytes32 public allowlistRoot;
    bytes32[] public allowlistProof;

    // Test events
    event ClaimConditionUpdate(address indexed token, uint256 id, AllowlistMintExtensionERC1155.ClaimCondition claimCondition);

    function _setupDomainSeparator(address _mintExtension) internal {
        bytes32 nameHash = keccak256(bytes("AllowlistMintExtensionERC1155"));
        bytes32 versionHash = keccak256(bytes("1"));
        bytes32 typehashEip712 = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        domainSeparator = keccak256(
            abi.encode(typehashEip712, nameHash, versionHash, block.chainid, _mintExtension)
        );
    }

    function setUp() public {

        developer = vm.addr(developerPKey);
        
        // Platform deploys mint extension.

        vm.startPrank(platformAdmin);

        address mintExtensionImpl = address(new AllowlistMintExtensionERC1155());

        bytes memory initData = abi.encodeWithSelector(
            AllowlistMintExtensionERC1155.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintExtensionProxy = address(new EIP1967Proxy(mintExtensionImpl, initData));
        mintExtension = AllowlistMintExtensionERC1155(mintExtensionProxy);

        // Platform deploys ERC1155 core implementation and clone factory.
        address erc1155CoreImpl = address(new ERC1155Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint extension for signature minting.
        _setupDomainSeparator(mintExtensionProxy);

        // Developer deploys proxy for ERC1155 core with AllowlistMintExtensionERC1155 preinstalled.
        vm.startPrank(developer);

        ERC1155Core.InitCall memory initCall;
        address[] memory preinstallExtensions = new address[](1);
        preinstallExtensions[0] = address(mintExtension);

        bytes memory erc1155InitData = abi.encodeWithSelector(
            ERC1155Core.initialize.selector,
            initCall,
            preinstallExtensions,
            developer, // core contract admin
            "Test ERC1155",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc1155Core = ERC1155Core(factory.deployProxyByImplementation(erc1155CoreImpl, erc1155InitData, bytes32("salt")));

        vm.stopPrank();

        // Setup allowlist
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";

        bytes memory result = vm.ffi(inputs);
        allowlistRoot = abi.decode(result, (bytes32));

        string[] memory proofInputs = new string[](2);
        proofInputs[0] = "node";
        proofInputs[1] = "test/scripts/getProof.ts";

        bytes memory proofResult = vm.ffi(proofInputs);
        allowlistProof = abi.decode(proofResult, (bytes32[]));

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");
        
        vm.label(address(erc1155Core), "ERC1155Core");
        vm.label(address(mintExtensionImpl), "AllowlistMintExtensionERC1155");
        vm.label(mintExtensionProxy, "ProxyAllowlistMintExtensionERC1155");
    }
    
    /*//////////////////////////////////////////////////////////////
                        TEST: setting claim conditions
    //////////////////////////////////////////////////////////////*/

    function test_setClaimCondition_state_only() public {

        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        vm.expectEmit(true, true, true, true);
        emit ClaimConditionUpdate(address(erc1155Core), 0, condition);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        AllowlistMintExtensionERC1155.ClaimCondition memory conditionStored = mintExtension.getClaimCondition(address(erc1155Core), 0);

        assertEq(conditionStored.price, condition.price);
        assertEq(conditionStored.availableSupply, condition.availableSupply);
        assertEq(conditionStored.allowlistMerkleRoot, condition.allowlistMerkleRoot);
    }

    function test_setClaimCondition_state_updateCurrentCondition() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        assertEq(erc1155Core.balanceOf(endUser, 0), 0);

        // End user mints a token
        vm.prank(endUser);
        erc1155Core.mint{value: condition.price}(endUser, 0, 1, abi.encode(allowlistProof));

        assertEq(erc1155Core.balanceOf(endUser, 0), 1);

        // Developer updates allowlist and endUser is excluded.
        AllowlistMintExtensionERC1155.ClaimCondition memory updatedCondition = condition;
        updatedCondition.allowlistMerkleRoot = bytes32("random");

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, updatedCondition));

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC1155.AllowlistMintExtensionNotInAllowlist.selector, address(erc1155Core), endUser));
        erc1155Core.mint{value: condition.price}(endUser, 0, 1, abi.encode(allowlistProof));
    }

    function test_setClaimCondition_revert_notAdminOfToken() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.expectRevert(abi.encodeWithSelector(ExtensionInstaller.HookInstallerUnauthorizedWrite.selector));
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting fee config
    //////////////////////////////////////////////////////////////*/

    function _setPaidMintClaimCondition(uint256 _id) internal {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, _id, condition));
    }

    function test_setDefaultFeeConfig_state() public {
        _setPaidMintClaimCondition(0);

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setDefaultFeeConfig.selector, feeConfig));

        IFeeConfig.FeeConfig memory feeConfigStored = mintExtension.getDefaultFeeConfig(address(erc1155Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc1155Core.mint{value: 1 ether}(endUser, 0, 1, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient
    }

    function test_setFeeConfigForToken_state() public {
        _setPaidMintClaimCondition(0);
        _setPaidMintClaimCondition(1);

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setDefaultFeeConfig.selector, feeConfig));

        IFeeConfig.FeeConfig memory feeConfigStored = mintExtension.getDefaultFeeConfig(address(erc1155Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc1155Core.mint{value: 1 ether}(endUser, 0, 1, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient

        // Set special platform fee for token ID 1.

        IFeeConfig.FeeConfig memory specialFeeConfig = feeConfig;
        specialFeeConfig.platformFeeBps = 2000; // 20%

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setFeeConfigForToken.selector, 1, specialFeeConfig));

        IFeeConfig.FeeConfig memory specialFeeConfigStored = mintExtension.getFeeConfigForToken(address(erc1155Core), 1);

        assertEq(specialFeeConfig.primarySaleRecipient, specialFeeConfigStored.primarySaleRecipient);
        assertEq(specialFeeConfig.platformFeeRecipient, specialFeeConfigStored.platformFeeRecipient);
        assertEq(specialFeeConfig.platformFeeBps, specialFeeConfigStored.platformFeeBps);

        // End user mints token id 1.
        assertEq(developer.balance, 0.9 ether);
        assertEq(platformAdmin.balance, 0.1 ether);

        vm.prank(endUser);
        erc1155Core.mint{value: 1 ether}(endUser, 1, 1, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether + 0.8 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether + 0.2 ether); // platform fee recipient
    }

    function test_setFeeConfig_revert_notAdminOfToken() public {
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(ExtensionInstaller.HookInstallerUnauthorizedWrite.selector));
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setDefaultFeeConfig.selector, feeConfig));
    }

    /*//////////////////////////////////////////////////////////////
                                TEST: mint
    //////////////////////////////////////////////////////////////*/

    function test_beforeMint_state() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        // Set primary sale recipient via fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: address(0),
            platformFeeBps: 0
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setDefaultFeeConfig.selector, feeConfig));

        // Mint tokens

        assertEq(developer.balance, 0);
        assertEq(mintExtension.getClaimCondition(address(erc1155Core), 0).availableSupply, 100);

        // End user mints a token
        vm.prank(endUser);
        erc1155Core.mint{value: condition.price * 5}(endUser, 0, 5, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.5 ether);
        assertEq(mintExtension.getClaimCondition(address(erc1155Core), 0).availableSupply, 95);
    }

    function test_beforeMint_revert_notEnoughSupply() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 10,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC1155.AllowlistMintExtensionInvalidQuantity.selector));
        erc1155Core.mint{value: condition.price * 11}(endUser, 0, 11, abi.encode(allowlistProof));

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC1155.AllowlistMintExtensionInvalidQuantity.selector));
        erc1155Core.mint{value: 0}(endUser, 0, 0, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_notInAllowlist() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC1155.AllowlistMintExtensionNotInAllowlist.selector, address(erc1155Core), address(0x1212)));
        erc1155Core.mint{value: condition.price}(address(0x1212), 0, 1, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_incorrectValueSent() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC1155.ClaimCondition memory condition = AllowlistMintExtensionERC1155.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        erc1155Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(AllowlistMintExtensionERC1155.setClaimCondition.selector, 0, condition));

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC1155.AllowlistMintExtensionIncorrectValueSent.selector));
        erc1155Core.mint{value: condition.price - 1}(endUser, 0, 1, abi.encode(allowlistProof));
    }
}