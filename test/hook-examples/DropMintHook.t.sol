// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";

import {DropMintHook} from "src/erc721/hooks/DropMintHook.sol";
import {LazyMintMetadataHook} from "src/erc721/hooks/LazyMintMetadataHook.sol";
import {SimpleDistributeHook} from "src/erc721/hooks/SimpleDistributeHook.sol";
import {RoyaltyHook} from "src/erc721/hooks/RoyaltyHook.sol";

import {ERC721Core, ERC721Initializable} from "src/erc721/ERC721Core.sol";
import {IERC721} from "src/interface/erc721/IERC721.sol";
import {ITokenHook} from "src/interface/extension/ITokenHook.sol";

contract DropMintHookTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721;
    DropMintHook public dropHook;
    LazyMintMetadataHook public lazyMintHook;
    RoyaltyHook public royaltyHook;
    SimpleDistributeHook public distributeHook;

    function setUp() public {
        // Setup up to enabling minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        CloneFactory cloneFactory = new CloneFactory();

        address dropHookProxyAddress = address(new MinimalUpgradeableRouter(platformAdmin, address(new DropMintHook())));
        dropHook = DropMintHook(dropHookProxyAddress);
        assertEq(dropHook.getNextTokenIdToMint(address(erc721)), 0);

        address lazyMintHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new LazyMintMetadataHook())));
        lazyMintHook = LazyMintMetadataHook(lazyMintHookProxyAddress);

        address royaltyHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new RoyaltyHook())));
        royaltyHook = RoyaltyHook(royaltyHookProxyAddress);

        address distributeHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new SimpleDistributeHook())));
        distributeHook = SimpleDistributeHook(distributeHookProxyAddress);

        address erc721Implementation = address(new ERC721Core());

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        bytes memory data = abi.encodeWithSelector(ERC721Core.initialize.selector, platformUser, "Test", "TST", "contractURI://");
        erc721 = ERC721Core(cloneFactory.deployProxyByImplementation(erc721Implementation, data, bytes32("salt")));

        vm.stopPrank();

        vm.label(address(erc721), "ERC721Core");
        vm.label(erc721Implementation, "ERC721CoreImpl");
        vm.label(address(dropHook), "DropMintHook");
        vm.label(address(lazyMintHook), "LazyMintHook");
        vm.label(address(royaltyHook), "RoyaltyHook");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");
    }

    function test_setupAndClaim() public {
        // [1] Developer: lazy mints token metadata on metadata hook
        uint256 quantityToLazymint = 100;
        string memory baseURI = "ipfs://Qme.../";

        vm.prank(platformUser);
        lazyMintHook.lazyMint(address(erc721), quantityToLazymint, baseURI, "");

        // [2] Developer: sets default royalty info on royalty hook
        uint256 royaltyBps = 1000; // 10%
        address royaltyRecipient = platformUser;

        vm.prank(platformUser);
        royaltyHook.setDefaultRoyaltyInfo(address(erc721), royaltyRecipient, royaltyBps);

        // [3] Developer: sets claim condition on drop mint hook and fee config on distribute hook
        DropMintHook.ClaimCondition memory condition;

        condition.maxClaimableSupply = quantityToLazymint;
        condition.quantityLimitPerWallet = 10;
        condition.pricePerToken = 0.1 ether;
        condition.currency = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        SimpleDistributeHook.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        vm.startPrank(platformUser);

        dropHook.setClaimCondition(address(erc721), condition, true);
        distributeHook.setFeeConfig(address(erc721), feeConfig);

        vm.stopPrank();

        // [4] Developer: installs hooks in ERC-721 contract
        vm.startPrank(platformUser);

        erc721.installHook(ITokenHook(address(dropHook)));
        erc721.installHook(ITokenHook(address(lazyMintHook)));
        erc721.installHook(ITokenHook(address(royaltyHook)));
        erc721.installHook(ITokenHook(address(distributeHook)));

        vm.stopPrank();

        // [5] Claimer: claims a token
        vm.deal(claimer, 0.1 ether);

        DropMintHook.AllowlistProof memory proof;
        bytes memory encodedArgs = abi.encode(condition.currency, condition.pricePerToken, proof);
        uint256 quantityToClaim = 1;

        vm.prank(claimer);
        erc721.mint{value: condition.pricePerToken * quantityToClaim}(claimer, quantityToClaim, encodedArgs);

        assertEq(erc721.balanceOf(claimer), quantityToClaim);
        assertEq(erc721.ownerOf(0), claimer);
        assertEq(erc721.totalSupply(), 1);
        assertEq(dropHook.getNextTokenIdToMint(address(erc721)), 1);
    }
}
