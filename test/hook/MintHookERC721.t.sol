// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "@murky/Merkle.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";

import {ERC721Core, HookInstaller} from "src/core/token/ERC721Core.sol";
import {MintHookERC721, ERC721Hook} from "src/hook/mint/MintHookERC721.sol";

import {IMintRequest} from "src/interface/common/IMintRequest.sol";
import {IClaimCondition} from "src/interface/common/IClaimCondition.sol";
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol";

contract MintHookERC721Test is Test {
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
    MintHookERC721 public MintHook;

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
    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, IClaimCondition.ClaimCondition condition, bool resetEligibility);

    function _setupDomainSeparator(address _MintHook) internal {
        bytes32 nameHash = keccak256(bytes("MintHookERC721"));
        bytes32 versionHash = keccak256(bytes("1"));
        bytes32 typehashEip712 =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, _MintHook));
    }

    function setUp() public {
        developer = vm.addr(developerPKey);

        // Platform deploys mint hook.

        vm.startPrank(platformAdmin);

        address MintHookImpl = address(new MintHookERC721());

        bytes memory initData = abi.encodeWithSelector(
            MintHookERC721.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address MintHookProxy = address(new EIP1967Proxy(MintHookImpl, initData));
        MintHook = MintHookERC721(MintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint hook for signature minting.
        _setupDomainSeparator(MintHookProxy);

        // Developer deploys proxy for ERC721 core with MintHookERC721 preinstalled.
        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(MintHook);

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
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory mdata = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            mdata[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        allowlistRoot = merkle.getRoot(mdata);
        allowlistProof = merkle.getProof(mdata, 0);

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");

        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(MintHookImpl), "MintHookERC721");
        vm.label(MintHookProxy, "ProxyMintHookERC721");
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting claim conditions
    //////////////////////////////////////////////////////////////*/

    function test_setClaimCondition_state_only() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: bytes32("root"),
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        vm.expectEmit(true, true, true, true);
        emit ClaimConditionUpdate(address(erc721Core), condition, false);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        IClaimCondition.ClaimCondition memory conditionStored = MintHook.getClaimCondition(address(erc721Core));

        assertEq(condition.startTimestamp, conditionStored.startTimestamp);
        assertEq(condition.endTimestamp, conditionStored.endTimestamp);
        assertEq(condition.maxClaimableSupply, conditionStored.maxClaimableSupply);
        assertEq(condition.supplyClaimed, conditionStored.supplyClaimed);
        assertEq(condition.quantityLimitPerWallet, conditionStored.quantityLimitPerWallet);
        assertEq(condition.merkleRoot, conditionStored.merkleRoot);
        assertEq(condition.pricePerToken, conditionStored.pricePerToken);
        assertEq(condition.currency, conditionStored.currency);
        assertEq(condition.metadata, conditionStored.metadata);
    }

    function test_setClaimCondition_state_newConditionResetEligibility() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.warp(condition.startTimestamp + 1);

        vm.prank(endUser);
        erc721Core.mint{value: condition.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(MintHook.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer sets new claim condition and resets claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, newCondition, true)
        );

        assertEq(MintHook.getClaimCondition(address(erc721Core)).supplyClaimed, 0); // since claim eligibility is reset
        assertEq(MintHook.getSupplyClaimedByWallet(address(erc721Core), endUser), 0);
        assertEq(MintHook.getClaimCondition(address(erc721Core)).metadata, newCondition.metadata);
    }

    function test_setClaimCondition_state_updateCurrentCondition() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.warp(condition.startTimestamp + 1);

        vm.prank(endUser);
        erc721Core.mint{value: condition.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(MintHook.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer updates current condition by not resettting claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        assertEq(MintHook.getClaimCondition(address(erc721Core)).supplyClaimed, 5); // since claim eligibility is reset
        assertEq(MintHook.getSupplyClaimedByWallet(address(erc721Core), endUser), 5);
        assertEq(MintHook.getClaimCondition(address(erc721Core)).metadata, newCondition.metadata);
    }

    function test_setClaimCondition_revert_notAdminOfToken() public {
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(HookInstaller.HookInstallerUnauthorizedWrite.selector));
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );
    }

    function test_setClaimCondition_revert_maxSupplyClaimedAlready() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.warp(condition.startTimestamp + 1);

        vm.prank(endUser);
        erc721Core.mint{value: condition.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(MintHook.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer sets new claim condition and resets claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";
        newCondition.maxClaimableSupply = 4;

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookMaxSupplyClaimed.selector));
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting fee config
    //////////////////////////////////////////////////////////////*/

    function _setPaidMintClaimCondition() internal {
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );
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
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        IFeeConfig.FeeConfig memory feeConfigStored = MintHook.getDefaultFeeConfig(address(erc721Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 1,
            pricePerToken: 1 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(req.minter, req.quantity, abi.encode(req));

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
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        IFeeConfig.FeeConfig memory feeConfigStored = MintHook.getDefaultFeeConfig(address(erc721Core));

        assertEq(feeConfig.primarySaleRecipient, feeConfigStored.primarySaleRecipient);
        assertEq(feeConfig.platformFeeRecipient, feeConfigStored.platformFeeRecipient);
        assertEq(feeConfig.platformFeeBps, feeConfigStored.platformFeeBps);

        // End user mints 1 token.
        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 1,
            pricePerToken: 1 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(req.minter, req.quantity, abi.encode(req));

        assertEq(developer.balance, 0.9 ether); // primary sale recipient
        assertEq(platformAdmin.balance, 0.1 ether); // platform fee recipient

        // Set special platform fee for token ID 1.

        IFeeConfig.FeeConfig memory specialFeeConfig = feeConfig;
        specialFeeConfig.platformFeeBps = 2000; // 20%

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG,
            0,
            abi.encodeWithSelector(MintHookERC721.setFeeConfigForToken.selector, 1, specialFeeConfig)
        );

        IFeeConfig.FeeConfig memory specialFeeConfigStored = MintHook.getFeeConfigForToken(address(erc721Core), 1);

        assertEq(specialFeeConfig.primarySaleRecipient, specialFeeConfigStored.primarySaleRecipient);
        assertEq(specialFeeConfig.platformFeeRecipient, specialFeeConfigStored.platformFeeRecipient);
        assertEq(specialFeeConfig.platformFeeBps, specialFeeConfigStored.platformFeeBps);

        // End user mints token id 1.
        assertEq(developer.balance, 0.9 ether);
        assertEq(platformAdmin.balance, 0.1 ether);

        IMintRequest.MintRequest memory req2 = req;
        req2.tokenId = 1;

        vm.prank(endUser);
        erc721Core.mint{value: 1 ether}(req2.minter, req2.quantity, abi.encode(req2));

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
        vm.expectRevert(abi.encodeWithSelector(HookInstaller.HookInstallerUnauthorizedWrite.selector));
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: permissionless mint
    //////////////////////////////////////////////////////////////*/

    function test_beforeMint_revert_nativeTokenPrice_msgValueNotEqPrice() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintHookERC721.MintHookInvalidPrice.selector,
                condition.pricePerToken * req.quantity,
                condition.pricePerToken * req.quantity - 1
            )
        );
        erc721Core.mint{value: condition.pricePerToken * req.quantity - 1}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_erc20Price_sentMsgValue() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.1 ether,
            currency: address(new MockERC20()),
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidPrice.selector, 0, 1 wei));
        erc721Core.mint{value: 1 wei}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_state_permissionlessMint_erc20Price() public {
        MockERC20 currency = new MockERC20();

        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: address(currency),
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for (uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(currency.balanceOf(developer), 0);
        assertEq(currency.balanceOf(platformAdmin), 0);

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        currency.mint(endUser, 100 ether);
        vm.prank(endUser);
        currency.approve(address(MintHook), condition.pricePerToken * 5);

        vm.prank(endUser);
        erc721Core.mint(req.minter, req.quantity, abi.encode(req));

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for (uint256 i = 0; i < 5; i += 1) {
            assertEq(erc721Core.ownerOf(i), endUser);
        }

        assertEq(currency.balanceOf(developer), 0.9 ether);
        assertEq(currency.balanceOf(platformAdmin), 0.1 ether);
    }

    function test_beforeMint_state_permissionlessMint_nativeTokenPrice() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for (uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for (uint256 i = 0; i < 5; i += 1) {
            assertEq(erc721Core.ownerOf(i), endUser);
        }

        assertEq(developer.balance, 0.9 ether);
        assertEq(platformAdmin.balance, 0.1 ether);
    }

    function test_beforeMint_revert_permissionlessMint_callerNotMintRequestToken() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(new ERC721Core()),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookNotToken.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(endUser, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_minterNotMintRequestMinter() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: developer, // not end user
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidRecipient.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(endUser, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_quantityToMintNotMintRequestQuantity() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidQuantity.selector, req.quantity - 1));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity - 1, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_mintNotStarted() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookMintNotStarted.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_mintEnded() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 100,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: allowlistRoot,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.warp(condition.endTimestamp);

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookMintEnded.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_notInAllowlist() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: bytes32("allowlist"),
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookNotInAllowlist.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_invalidCurrency() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: bytes32(""),
            pricePerToken: 0.2 ether,
            currency: address(new MockERC20()),
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: address(new MockERC20()),
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(
            abi.encodeWithSelector(MintHookERC721.MintHookInvalidCurrency.selector, condition.currency, req.currency)
        );
        erc721Core.mint(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_invalidPrice() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 10,
            merkleRoot: bytes32(""),
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.01 ether,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintHookERC721.MintHookInvalidPrice.selector, condition.pricePerToken, req.pricePerToken
            )
        );
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_invalidQuantity() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 1000,
            supplyClaimed: 0,
            quantityLimitPerWallet: 5,
            merkleRoot: bytes32(""),
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        req.quantity = condition.quantityLimitPerWallet + 1;

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidQuantity.selector, req.quantity));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        req.quantity = 0;

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidQuantity.selector, req.quantity));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionlessMint_maxSupplyClaimed() public {
        // Developer sets claim condition
        IClaimCondition.ClaimCondition memory condition = IClaimCondition.ClaimCondition({
            startTimestamp: 0,
            endTimestamp: 200,
            maxClaimableSupply: 9,
            supplyClaimed: 0,
            quantityLimitPerWallet: 5,
            merkleRoot: bytes32(""),
            pricePerToken: 0,
            currency: NATIVE_TOKEN,
            metadata: "ipfs:Qme123"
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setClaimCondition.selector, condition, false)
        );

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // End user claims 5 tokens.

        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: condition.pricePerToken,
            currency: condition.currency,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 0,
            sigUid: bytes32("random-1")
        });

        vm.prank(endUser);
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        req.minter = developer;

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookMaxSupplyClaimed.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(developer, req.quantity, abi.encode(req));
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: permissioned mint
    //////////////////////////////////////////////////////////////*/

    function _signMintRequest(IMintRequest.MintRequest memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            TYPEHASH,
            _req.token,
            _req.tokenId,
            _req.minter,
            _req.quantity,
            _req.pricePerToken,
            _req.currency,
            _req.allowlistProof,
            keccak256(bytes("")),
            _req.sigValidityStartTimestamp,
            _req.sigValidityEndTimestamp,
            _req.sigUid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function test_beforeMint_state_permissionedMint_erc20Price() public {
        MockERC20 currency = new MockERC20();
        currency.mint(endUser, 100 ether);
        vm.prank(endUser);
        currency.approve(address(MintHook), 100 ether);

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // Sign mint request
        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.2 ether,
            currency: address(currency),
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 200,
            sigUid: bytes32("random-1")
        });

        bytes memory sig = _signMintRequest(req, developerPKey);
        req.permissionSignature = sig;

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for (uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(currency.balanceOf(developer), 0);
        assertEq(currency.balanceOf(platformAdmin), 0);

        vm.prank(endUser);
        erc721Core.mint(req.minter, req.quantity, abi.encode(req));

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for (uint256 i = 0; i < 5; i += 1) {
            assertEq(erc721Core.ownerOf(i), endUser);
        }

        assertEq(currency.balanceOf(developer), 0.9 ether);
        assertEq(currency.balanceOf(platformAdmin), 0.1 ether);
    }

    function test_beforeMint_state_permissionedMint_nativeTokenPrice() public {
        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // Sign mint request
        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 200,
            sigUid: bytes32("random-1")
        });

        bytes memory sig = _signMintRequest(req, developerPKey);
        req.permissionSignature = sig;

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for (uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);

        vm.prank(endUser);
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(MintHook.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for (uint256 i = 0; i < 5; i += 1) {
            assertEq(erc721Core.ownerOf(i), endUser);
        }

        assertEq(developer.balance, 0.9 ether);
        assertEq(platformAdmin.balance, 0.1 ether);
    }

    function test_beforeMint_revert_permissionedMint_invalidSignature() public {
        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // Sign mint request
        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 200,
            sigUid: bytes32("random-1")
        });

        bytes memory sig = _signMintRequest(req, 12345);
        req.permissionSignature = sig;

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookInvalidSignature.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionedMint_requestExpired() public {
        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // Sign mint request
        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 200,
            sigUid: bytes32("random-1")
        });

        bytes memory sig = _signMintRequest(req, developerPKey);
        req.permissionSignature = sig;

        vm.warp(req.sigValidityEndTimestamp);

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookRequestExpired.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }

    function test_beforeMint_revert_permissionedMint_requestUsed() public {
        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(
            BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );

        // Sign mint request
        IMintRequest.MintRequest memory req = IMintRequest.MintRequest({
            token: address(erc721Core),
            tokenId: 0,
            minter: endUser,
            quantity: 5,
            pricePerToken: 0.2 ether,
            currency: NATIVE_TOKEN,
            allowlistProof: allowlistProof,
            permissionSignature: new bytes(0),
            sigValidityStartTimestamp: 0,
            sigValidityEndTimestamp: 200,
            sigUid: bytes32("random-1")
        });

        bytes memory sig = _signMintRequest(req, developerPKey);
        req.permissionSignature = sig;

        vm.prank(endUser);
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintHookERC721.MintHookRequestUsed.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }
}
