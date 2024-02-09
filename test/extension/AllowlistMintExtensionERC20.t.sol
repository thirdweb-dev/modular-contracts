// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IExtension} from "src/interface/extension/IExtension.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {AllowlistMintExtensionERC20, ERC20Extension} from "src/extension/mint/AllowlistMintExtensionERC20.sol";
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol"; 

contract AllowlistMintExtensionERC20Test is Test {

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);

    uint256 developerPKey = 100;
    address public developer;
    
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC20Core public erc20Core;
    AllowlistMintExtensionERC20 public mintExtension;

    // Test params
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );
    bytes32 public domainSeparator;
    
    bytes32 public allowlistRoot;
    bytes32[] public allowlistProof;

    // Test events
    event ClaimConditionUpdate(address indexed token, AllowlistMintExtensionERC20.ClaimCondition claimCondition);

    function _setupDomainSeparator(address _mintExtension) internal {
        bytes32 nameHash = keccak256(bytes("AllowlistMintExtensionERC20"));
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

        address mintExtensionImpl = address(new AllowlistMintExtensionERC20());

        bytes memory initData = abi.encodeWithSelector(
            AllowlistMintExtensionERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintExtensionProxy = address(new EIP1967Proxy(mintExtensionImpl, initData));
        mintExtension = AllowlistMintExtensionERC20(mintExtensionProxy);

        // Platform deploys ERC20 core implementation and clone factory.
        address erc20CoreImpl = address(new ERC20Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint extension for signature minting.
        _setupDomainSeparator(mintExtensionProxy);

        // Developer deploys proxy for ERC20 core with AllowlistMintExtensionERC20 preinstalled.
        vm.startPrank(developer);

        ERC20Core.InitCall memory initCall;
        address[] memory preinstallExtensions = new address[](1);
        preinstallExtensions[0] = address(mintExtension);

        bytes memory erc20InitData = abi.encodeWithSelector(
            ERC20Core.initialize.selector,
            initCall,
            preinstallExtensions,
            developer, // core contract admin
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc20Core = ERC20Core(factory.deployProxyByImplementation(erc20CoreImpl, erc20InitData, bytes32("salt")));

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
        
        vm.label(address(erc20Core), "ERC20Core");
        vm.label(address(mintExtensionImpl), "AllowlistMintExtensionERC20");
        vm.label(mintExtensionProxy, "ProxyAllowlistMintExtensionERC20");
    }
    
    /*//////////////////////////////////////////////////////////////
                        TEST: setting claim conditions
    //////////////////////////////////////////////////////////////*/

    function test_setClaimCondition_state_only() public {

        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        vm.expectEmit(true, true, true, true);
        emit ClaimConditionUpdate(address(erc20Core), condition);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        AllowlistMintExtensionERC20.ClaimCondition memory conditionStored = mintExtension.getClaimCondition(address(erc20Core));

        assertEq(conditionStored.price, condition.price);
        assertEq(conditionStored.availableSupply, condition.availableSupply);
        assertEq(conditionStored.allowlistMerkleRoot, condition.allowlistMerkleRoot);
    }

    function test_setClaimCondition_state_updateCurrentCondition() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        assertEq(erc20Core.balanceOf(endUser), 0);

        // End user mints a token
        vm.prank(endUser);
        erc20Core.mint{value: condition.price}(endUser, 1 ether, abi.encode(allowlistProof));

        assertEq(erc20Core.balanceOf(endUser), 1 ether);

        // Developer updates allowlist and endUser is excluded.
        AllowlistMintExtensionERC20.ClaimCondition memory updatedCondition = condition;
        updatedCondition.allowlistMerkleRoot = bytes32("random");

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), updatedCondition);

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionNotInAllowlist.selector, address(erc20Core), endUser));
        erc20Core.mint{value: condition.price}(endUser, 1 ether, abi.encode(allowlistProof));
    }

    function test_setClaimCondition_revert_notAdminOfToken() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionsNotAuthorized.selector));
        mintExtension.setClaimCondition(address(erc20Core), condition);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting fee config
    //////////////////////////////////////////////////////////////*/

    function _setPaidMintClaimCondition() internal {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);
    }

    function test_setDefaultFeeConfig_state() public {
        _setPaidMintClaimCondition();

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        mintExtension.setDefaultFeeConfig(address(erc20Core), feeConfig);

        IFeeConfig.FeeConfig memory feeConfigStored = mintExtension.getFeeConfig(address(erc20Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc20Core.mint{value: 1 ether}(endUser, 1 ether, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient
    }

    function test_setFeeConfig_revert_notAdminOfToken() public {
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionsNotAuthorized.selector));
        mintExtension.setDefaultFeeConfig(address(erc20Core), feeConfig);
    }

    /*//////////////////////////////////////////////////////////////
                                TEST: mint
    //////////////////////////////////////////////////////////////*/

    function test_beforeMint_state() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        // Set primary sale recipient via fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: address(0),
            platformFeeBps: 0
        });

        vm.prank(developer);
        mintExtension.setDefaultFeeConfig(address(erc20Core), feeConfig);

        // Mint tokens

        assertEq(developer.balance, 0);
        assertEq(mintExtension.getClaimCondition(address(erc20Core)).availableSupply, 100 ether);

        // End user mints a token
        vm.prank(endUser);
        erc20Core.mint{value: condition.price * 5}(endUser, 5 ether, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.5 ether);
        assertEq(mintExtension.getClaimCondition(address(erc20Core)).availableSupply, 95 ether);
    }

    function test_beforeMint_revert_notEnoughSupply() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 10,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionInvalidQuantity.selector));
        erc20Core.mint{value: condition.price * 11}(endUser, 11, abi.encode(allowlistProof));

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionInvalidQuantity.selector));
        erc20Core.mint{value: 0}(endUser, 0, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_notInAllowlist() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionNotInAllowlist.selector, address(erc20Core), address(0x1212)));
        erc20Core.mint{value: condition.price}(address(0x1212), 1, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_incorrectValueSent() public {
        // Developer sets claim condition
        AllowlistMintExtensionERC20.ClaimCondition memory condition = AllowlistMintExtensionERC20.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintExtension.setClaimCondition(address(erc20Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintExtensionERC20.AllowlistMintExtensionIncorrectValueSent.selector));
        erc20Core.mint{value: condition.price - 1}(endUser, 1 ether, abi.encode(allowlistProof));
    }
}