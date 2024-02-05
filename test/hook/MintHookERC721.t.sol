// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";

import {IHook} from "src/interface/hook/IHook.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
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
    address public developer = address(0x456);
    address public endUser = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721Core;
    MintHookERC721 public mintHook;

    // Test params
    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address minter,uint256 quantity,uint256 pricePerToken,address currency,bytes32[] allowlistProof,bytes permissionSignature,uint128 sigValidityStartTimestamp,uint128 sigValidityEndTimestamp,bytes32 sigUid)"
    );
    bytes32 internal domainSeparator;

    // Test events
    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, IClaimCondition.ClaimCondition condition, bool resetEligibility);

    function _setupDomainSeparator(address _mintHook) internal {
        bytes32 nameHash = keccak256(bytes("MintHookERC721"));
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

        address mintHookImpl = address(new MintHookERC721());

        bytes memory initData = abi.encodeWithSelector(
            MintHookERC721.initialize.selector,
            platformAdmin // upgradeAdmin
        );
        address mintHookProxy = address(new EIP1967Proxy(mintHookImpl, initData));
        mintHook = MintHookERC721(mintHookProxy);

        // Platform deploys ERC721 core implementation and clone factory.
        address erc721CoreImpl = address(new ERC721Core());
        CloneFactory factory = new CloneFactory();

        vm.stopPrank();

        // Setup domain separator of mint hook for signature minting.
        _setupDomainSeparator(mintHookProxy);

        // Developer deploys proxy for ERC721 core with MintHookERC721 preinstalled.
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

        // Set labels
        vm.deal(endUser, 100 ether);

        vm.label(platformAdmin, "Admin");
        vm.label(developer, "Developer");
        vm.label(endUser, "Claimer");
        
        vm.label(address(erc721Core), "ERC721Core");
        vm.label(address(mintHookImpl), "MintHookERC721");
        vm.label(mintHookProxy, "ProxyMintHookERC721");
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

    function test_setFeeConfig_state() public {}
    
    function test_setFeeConfig_state_onlyPrimarySale() public {}

    function test_setFeeConfig_state_primarySaleWithPlatformFee() public {}

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
}