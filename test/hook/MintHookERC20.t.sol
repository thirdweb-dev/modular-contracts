// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {MintHookERC20, ERC20Hook} from "src/hook/mint/MintHookERC20.sol";

import {IMintRequest} from "src/interface/common/IMintRequest.sol"; 
import {IClaimCondition} from "src/interface/common/IClaimCondition.sol"; 
import {IFeeConfig} from "src/interface/common/IFeeConfig.sol"; 

contract MintHookERC20Test is Test {

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC20Core public erc20Core;
    MintHookERC20 public mintHook;

    // Test params
    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );
    bytes32 internal domainSeparator;

    // Test events
    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, IClaimCondition.ClaimCondition condition, bool resetEligibility);

    function _setupDomainSeparator(address _mintHook) internal {
        bytes32 nameHash = keccak256(bytes("MintHookERC20"));
        bytes32 versionHash = keccak256(bytes("1"));
        bytes32 typehashEip712 = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        domainSeparator = keccak256(
            abi.encode(typehashEip712, nameHash, versionHash, block.chainid, _mintHook)
        );
    }

    function _setUp() public {
        
        // Platform deploys mint hook.

        vm.startPrank(platformAdmin);

        address mintHookImpl = address(new MintHookERC20());

        bytes memory initData = abi.encodeWithSelector(
            MintHookERC20.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintHookProxy = address(new EIP1967Proxy(mintHookImpl, initData));
        mintHook = MintHookERC20(mintHookProxy);

        // Platform deploys ERC20 core implementation and clone factory.
        address erc20CoreImpl = address(new ERC20Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint hook for signature minting.
        _setupDomainSeparator(mintHookProxy);

        // Developer deploys proxy for ERC20 core with MintHookERC20 preinstalled.
        vm.startPrank(developer);

        ERC20Core.InitCall memory initCall;
        address[] memory preinstallHooks = new address[](1);
        preinstallHooks[0] = address(mintHook);

        bytes memory erc20InitData = abi.encodeWithSelector(
            ERC20Core.initialize.selector,
            initCall,
            preinstallHooks,
            developer, // core contract admin
            "Test ERC20",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0" // mock contract URI of actual length
        );
        erc20Core = ERC20Core(factory.deployProxyByImplementation(erc20CoreImpl, erc20InitData, bytes32("salt")));

        vm.stopPrank();

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");
        
        vm.label(address(erc20Core), "ERC20Core");
        vm.label(address(mintHookImpl), "MintHookERC20");
        vm.label(mintHookProxy, "ProxyMintHookERC20");
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: setting claim conditions
    //////////////////////////////////////////////////////////////*/

    function test_setClaimConditions_state() public {}

    function test_setClaimConditions_state_newConditionResetEligibility() public {}

    function test_setClaimConditions_state_updateCurrentCondition() public {}

    function test_setClaimConditions_revert_notAdminOfToken() public {}

    function test_setClaimConditions_revert_maxSupplyClaimedAlready() public {}

    /*//////////////////////////////////////////////////////////////
                        TEST: setting fee config
    //////////////////////////////////////////////////////////////*/

    function test_setDefaultFeeConfig_state() public {}

    function test_setFeeConfigForToken_state() public {}
    
    function test_setDefaultFeeConfig_state_onlyPrimarySale() public {}

    function test_setDefaultFeeConfig_state_primarySaleWithPlatformFee() public {}

    function test_setFeeConfigForToken_state_overridePrimarySaleRecipient() public {}
    
    function test_setFeeConfigForToken_state_overridePlatformFee() public {}

    function test_setFeeConfig_revert_notAdminOfToken() public {}

    /*//////////////////////////////////////////////////////////////
                        TEST: beforeMint
    //////////////////////////////////////////////////////////////*/

    function test_beforeMint_revert_nativeTokenPrice_msgValueNotEqPrice() public {}

    function test_beforeMint_revert_erc20Price_sentMsgValue() public {}

    function test_beforeMint_state_permissionlessMint_erc20Price() public {}
    
    function test_beforeMint_state_permissionlessMint_nativeTokenPrice() public {}

    function test_beforeMint_revert_permissionlessMint_callerNotMintRequestToken() public {}

    function test_beforeMint_revert_permissionlessMint_minterNotMintRequestMinter() public {}

    function test_beforeMint_revert_permissionlessMint_quantityToMintNotMintRequestQuantity() public {}

    function test_beforeMint_revert_permissionlessMint_mintNotStarted() public {}

    function test_beforeMint_revert_permissionlessMint_mintEnded() public {}

    function test_beforeMint_revert_permissionlessMint_notInAllowlist() public {}

    function test_beforeMint_revert_permissionlessMint_invalidCurrency() public {}

    function test_beforeMint_revert_permissionlessMint_invalidPrice() public {}

    function test_beforeMint_revert_permissionlessMint_invalidQuantity() public {}

    function test_beforeMint_revert_permissionlessMint_maxSupplyClaimed() public {}

    function test_beforeMint_state_permissionedMint_erc20Price() public {}
    
    function test_beforeMint_state_permissionedMint_nativeTokenPrice() public {}

    function test_beforeMint_revert_permissionedMint_invalidSignature() public {}

    function test_beforeMint_revert_permissionedMint_requestExpired() public {}

    function test_beforeMint_revert_permissionedMint_requestUsed() public {}
}