// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {AllowlistMintHookERC721, ERC721Hook} from "src/hook/mint/AllowlistMintHookERC721.sol";
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol"; 

contract AllowlistMintHookERC721Test is Test {

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);

    uint256 developerPKey = 100;
    address public developer;
    
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721Core;
    AllowlistMintHookERC721 public mintHook;

    // Test params
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );
    bytes32 public domainSeparator;
    
    bytes32 public allowlistRoot;
    bytes32[] public allowlistProof;

    // Test events
    event ClaimConditionUpdate(address indexed token, AllowlistMintHookERC721.ClaimCondition claimCondition);

    function _setupDomainSeparator(address _mintHook) internal {
        bytes32 nameHash = keccak256(bytes("AllowlistMintHookERC721"));
        bytes32 versionHash = keccak256(bytes("1"));
        bytes32 typehashEip712 = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        domainSeparator = keccak256(
            abi.encode(typehashEip712, nameHash, versionHash, block.chainid, _mintHook)
        );
    }

    function setUp() public {

        developer = vm.addr(developerPKey);
        
        // Platform deploys mint hook.

        vm.startPrank(platformAdmin);

        address mintHookImpl = address(new AllowlistMintHookERC721());

        bytes memory initData = abi.encodeWithSelector(
            AllowlistMintHookERC721.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintHookProxy = address(new EIP1967Proxy(mintHookImpl, initData));
        mintHook = AllowlistMintHookERC721(mintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint hook for signature minting.
        _setupDomainSeparator(mintHookProxy);

        // Developer deploys proxy for ERC721 core with AllowlistMintHookERC721 preinstalled.
        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(mintHook);

        bytes memory erc721InitData = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            preinstallHooks,
            developer, // core contract admin
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc721Core = ERC721Core(factory.deployProxyByImplementation(erc721CoreImpl, erc721InitData, bytes32("salt")));

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
        
        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(mintHookImpl), "AllowlistMintHookERC721");
        vm.label(mintHookProxy, "ProxyAllowlistMintHookERC721");
    }
    
    /*//////////////////////////////////////////////////////////////
                        TEST: setting claim conditions
    //////////////////////////////////////////////////////////////*/

    function test_setClaimCondition_state_only() public {

        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        vm.expectEmit(true, true, true, true);
        emit ClaimConditionUpdate(address(erc721Core), condition);
        mintHook.setClaimCondition(address(erc721Core), condition);

        AllowlistMintHookERC721.ClaimCondition memory conditionStored = mintHook.getClaimCondition(address(erc721Core));

        assertEq(conditionStored.price, condition.price);
        assertEq(conditionStored.availableSupply, condition.availableSupply);
        assertEq(conditionStored.allowlistMerkleRoot, condition.allowlistMerkleRoot);
    }

    function test_setClaimCondition_state_updateCurrentCondition() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);

        vm.expectRevert();
        erc721Core.ownerOf(0);

        // End user mints a token
        vm.prank(endUser);
        erc721Core.mint{value: condition.price}(endUser, 1, abi.encode(allowlistProof));

        assertEq(erc721Core.ownerOf(0), endUser);

        // Developer updates allowlist and endUser is excluded.
        AllowlistMintHookERC721.ClaimCondition memory updatedCondition = condition;
        updatedCondition.allowlistMerkleRoot = bytes32("random");

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), updatedCondition);

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookNotInAllowlist.selector, address(erc721Core), endUser));
        erc721Core.mint{value: condition.price}(endUser, 1, abi.encode(allowlistProof));
    }

    function test_setClaimCondition_revert_notAdminOfToken() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookNotAuthorized.selector));
        mintHook.setClaimCondition(address(erc721Core), condition);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting fee config
    //////////////////////////////////////////////////////////////*/

    function _setPaidMintClaimCondition() internal {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);
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
        mintHook.setDefaultFeeConfig(address(erc721Core), feeConfig);

        IFeeConfig.FeeConfig memory feeConfigStored = mintHook.getDefaultFeeConfig(address(erc721Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(endUser, 1, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient
    }

    function test_setFeeConfigForToken_state() public {
        _setPaidMintClaimCondition();

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        mintHook.setDefaultFeeConfig(address(erc721Core), feeConfig);

        IFeeConfig.FeeConfig memory feeConfigStored = mintHook.getDefaultFeeConfig(address(erc721Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(endUser, 1, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient

        // Set special platform fee for token ID 1.

        IFeeConfig.FeeConfig memory specialFeeConfig = feeConfig;
        specialFeeConfig.platformFeeBps = 2000; // 20%

        vm.prank(developer);
        mintHook.setFeeConfigForToken(address(erc721Core), 1, specialFeeConfig);

        IFeeConfig.FeeConfig memory specialFeeConfigStored = mintHook.getFeeConfigForToken(address(erc721Core), 1);

        assertEq(specialFeeConfig.primarySaleRecipient, specialFeeConfigStored.primarySaleRecipient);
        assertEq(specialFeeConfig.platformFeeRecipient, specialFeeConfigStored.platformFeeRecipient);
        assertEq(specialFeeConfig.platformFeeBps, specialFeeConfigStored.platformFeeBps);

        // End user mints token id 1.
        assertEq(developer.balance, 0.9 ether);
        assertEq(platformAdmin.balance, 0.1 ether);

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(endUser, 1, abi.encode(allowlistProof));

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
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookNotAuthorized.selector));
        mintHook.setDefaultFeeConfig(address(erc721Core), feeConfig);
    }

    /*//////////////////////////////////////////////////////////////
                                TEST: mint
    //////////////////////////////////////////////////////////////*/

    function test_beforeMint_state() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);

        // Set primary sale recipient via fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: address(0),
            platformFeeBps: 0
        });

        vm.prank(developer);
        mintHook.setDefaultFeeConfig(address(erc721Core), feeConfig);

        // Mint tokens

        assertEq(developer.balance, 0);
        assertEq(mintHook.getClaimCondition(address(erc721Core)).availableSupply, 100);
        assertEq(mintHook.getNextTokenIdToMint(address(erc721Core)), 0);

        // End user mints a token
        vm.prank(endUser);
        erc721Core.mint{value: condition.price * 5}(endUser, 5, abi.encode(allowlistProof));

        assertEq(developer.balance, 0.5 ether);
        assertEq(mintHook.getClaimCondition(address(erc721Core)).availableSupply, 95);
        assertEq(mintHook.getNextTokenIdToMint(address(erc721Core)), 5);
    }

    function test_beforeMint_revert_notEnoughSupply() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 10,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookInvalidQuantity.selector));
        erc721Core.mint{value: condition.price * 11}(endUser, 11, abi.encode(allowlistProof));

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookInvalidQuantity.selector));
        erc721Core.mint{value: 0}(endUser, 0, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_notInAllowlist() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookNotInAllowlist.selector, address(erc721Core), address(0x1212)));
        erc721Core.mint{value: condition.price}(address(0x1212), 1, abi.encode(allowlistProof));
    }

    function test_beforeMint_revert_incorrectValueSent() public {
        // Developer sets claim condition
        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot
        });

        vm.prank(developer);
        mintHook.setClaimCondition(address(erc721Core), condition);

        // End user mints a token
        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(AllowlistMintHookERC721.AllowlistMintHookIncorrectValueSent.selector));
        erc721Core.mint{value: condition.price - 1}(endUser, 1, abi.encode(allowlistProof));
    }
}