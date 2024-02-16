// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IExtension} from "src/interface/extension/IExtension.sol";

import {ERC721Core, ExtensionInstaller} from "src/core/token/ERC721Core.sol";
import {MintExtensionERC721, ERC721Extension} from "src/extension/mint/MintExtensionERC721.sol";

import {IMintRequest} from "src/interface/common/IMintRequest.sol"; 
import {IClaimCondition} from "src/interface/common/IClaimCondition.sol"; 
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol"; 

contract MintExtensionERC721Test is Test {

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
    MintExtensionERC721 public mintExtension;

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

    function _setupDomainSeparator(address _mintExtension) internal {
        bytes32 nameHash = keccak256(bytes("MintExtensionERC721"));
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

        address mintExtensionImpl = address(new MintExtensionERC721());

        bytes memory initData = abi.encodeWithSelector(
            MintExtensionERC721.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintExtensionProxy = address(new EIP1967Proxy(mintExtensionImpl, initData));
        mintExtension = MintExtensionERC721(mintExtensionProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint extension for signature minting.
        _setupDomainSeparator(mintExtensionProxy);

        // Developer deploys proxy for ERC721 core with MintExtensionERC721 preinstalled.
        vm.startPrank(developer);

        ERC721Core.InitCall memory initCall;
        address[] memory preinstallExtensions = new address[](1);
        preinstallExtensions[0] = address(mintExtension);

        bytes memory erc721InitData = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            preinstallExtensions,
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
        vm.label(address(mintExtensionImpl), "MintExtensionERC721");
        vm.label(mintExtensionProxy, "ProxyMintExtensionERC721");
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));

        IClaimCondition.ClaimCondition memory conditionStored = mintExtension.getClaimCondition(address(erc721Core));

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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));

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
        assertEq(mintExtension.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer sets new claim condition and resets claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, newCondition, true));

        assertEq(mintExtension.getClaimCondition(address(erc721Core)).supplyClaimed, 0); // since claim eligibility is reset
        assertEq(mintExtension.getSupplyClaimedByWallet(address(erc721Core), endUser), 0);
        assertEq(mintExtension.getClaimCondition(address(erc721Core)).metadata, newCondition.metadata);
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));

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
        assertEq(mintExtension.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer updates current condition by not resettting claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));

        assertEq(mintExtension.getClaimCondition(address(erc721Core)).supplyClaimed, 5); // since claim eligibility is reset
        assertEq(mintExtension.getSupplyClaimedByWallet(address(erc721Core), endUser), 5);
        assertEq(mintExtension.getClaimCondition(address(erc721Core)).metadata, newCondition.metadata);
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
        vm.expectRevert(abi.encodeWithSelector(ExtensionInstaller.HookInstallerUnauthorizedWrite.selector));
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));

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
        assertEq(mintExtension.getClaimCondition(address(erc721Core)).supplyClaimed, 5);

        // Developer sets new claim condition and resets claim eligibility of all wallets.
        IClaimCondition.ClaimCondition memory newCondition = condition;
        newCondition.metadata = "ipfs:Qme456";
        newCondition.maxClaimableSupply = 4;

        vm.prank(developer);
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionMaxSupplyClaimed.selector));
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));

        IFeeConfig.FeeConfig memory feeConfigStored = mintExtension.getDefaultFeeConfig(address(erc721Core));

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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));

        IFeeConfig.FeeConfig memory feeConfigStored = mintExtension.getDefaultFeeConfig(address(erc721Core));

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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setFeeConfigForToken.selector, 1, specialFeeConfig));

        IFeeConfig.FeeConfig memory specialFeeConfigStored = mintExtension.getFeeConfigForToken(address(erc721Core), 1);

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
        vm.expectRevert(abi.encodeWithSelector(ExtensionInstaller.HookInstallerUnauthorizedWrite.selector));
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));        

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidPrice.selector, condition.pricePerToken * req.quantity, condition.pricePerToken * req.quantity - 1));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));        

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidPrice.selector, 0, 1 wei));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

        // End user claims 5 tokens.

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for(uint256 i = 0; i < 5; i += 1) {
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
        currency.approve(address(mintExtension), condition.pricePerToken * 5);

        vm.prank(endUser);
        erc721Core.mint(req.minter, req.quantity, abi.encode(req));

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for(uint256 i = 0; i < 5; i += 1) {
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

        // End user claims 5 tokens.

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for(uint256 i = 0; i < 5; i += 1) {
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

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for(uint256 i = 0; i < 5; i += 1) {
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionNotToken.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidRecipient.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidQuantity.selector, req.quantity - 1));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionMintNotStarted.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionMintEnded.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionNotInAllowlist.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidCurrency.selector, condition.currency, req.currency));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidPrice.selector, condition.pricePerToken, req.pricePerToken));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));    

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidQuantity.selector, req.quantity));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        req.quantity = 0;

        vm.prank(endUser);
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidQuantity.selector, req.quantity));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setClaimCondition.selector, condition, false));    

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));

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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionMaxSupplyClaimed.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(developer, req.quantity, abi.encode(req));
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: permissioned mint
    //////////////////////////////////////////////////////////////*/

    function _signMintRequest(
        IMintRequest.MintRequest memory _req,
        uint256 _privateKey
    ) internal view returns (bytes memory) {
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
        currency.approve(address(mintExtension), 100 ether);

        // Developer sets fee config
        IFeeConfig.FeeConfig memory feeConfig = IFeeConfig.FeeConfig({
            primarySaleRecipient: developer,
            platformFeeRecipient: platformAdmin,
            platformFeeBps: 1000 // 10%
        });

        vm.prank(developer);
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        
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

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for(uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(currency.balanceOf(developer), 0);
        assertEq(currency.balanceOf(platformAdmin), 0);
        
        vm.prank(endUser);
        erc721Core.mint(req.minter, req.quantity, abi.encode(req));

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for(uint256 i = 0; i < 5; i += 1) {
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        
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

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 0);
        assertEq(erc721Core.balanceOf(endUser), 0);
        assertEq(erc721Core.totalSupply(), 0);

        for(uint256 i = 0; i < 5; i += 1) {
            vm.expectRevert();
            erc721Core.ownerOf(i);
        }

        assertEq(developer.balance, 0);
        assertEq(platformAdmin.balance, 0);
        
        vm.prank(endUser);
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));

        assertEq(mintExtension.getNextTokenIdToMint(address(erc721Core)), 5);
        assertEq(erc721Core.balanceOf(endUser), 5);
        assertEq(erc721Core.totalSupply(), 5);

        for(uint256 i = 0; i < 5; i += 1) {
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        
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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionInvalidSignature.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        
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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionRequestExpired.selector));
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
        erc721Core.hookFunctionWrite(BEFORE_MINT_FLAG, 0, abi.encodeWithSelector(MintExtensionERC721.setDefaultFeeConfig.selector, feeConfig));
        
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
        vm.expectRevert(abi.encodeWithSelector(MintExtensionERC721.MintExtensionRequestUsed.selector));
        erc721Core.mint{value: req.pricePerToken * req.quantity}(req.minter, req.quantity, abi.encode(req));
    }
}