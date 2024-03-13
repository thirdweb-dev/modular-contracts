// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "@murky/Merkle.sol";

import "@solady/utils/LibClone.sol";
import "@solady/utils/UUPSUpgradeable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {EIP1967Proxy} from "src/infra/EIP1967Proxy.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";
import {MockOneHookImpl, MockFourHookImpl} from "test/mocks/MockHookImpl.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC721Hook, AllowlistMintHookERC721} from "src/hook/mint/AllowlistMintHookERC721.sol";
import {LazyMintHook} from "src/hook/metadata/LazyMintHook.sol";
import {RoyaltyHook} from "src/hook/royalty/RoyaltyHook.sol";
import {IERC721} from "src/interface/eip/IERC721.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {IERC721Hook} from "src/interface/hook/IERC721Hook.sol";
import {IHookInstaller} from "src/interface/hook/IHookInstaller.sol";

/**
 *  This test showcases how users would use ERC-721 contracts on the thirdweb platform.
 *
 *  CORE CONTRACTS:
 *
 *  Developers will deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-721 Core contract.
 *
 *      - This contract is initializable, and meant to be used with proxy contracts.
 *      - Implements the token standard (and the respective token metadata standard).
 *      - Uses the role based permission model of the `Permission` contract.
 *      - Implements the `IHookInstaller` interface.
 *
 *  HOOKS:
 *
 *  Core contracts work with "extensions". There is a fixed set of 6 extensions supported by the core contract:
 *
 *      - BeforeMint: called before a token is minted in the ERC721Core.mint call.
 *      - BeforeTransfer: called before a token is transferred in the ERC721.transferFrom call.
 *      - BeforeBurn: called before a token is burned in the ERC721.burn call.
 *      - BeforeApprove: called before the ERC721.approve call.
 *      - Token URI: called when the ERC721Metadata.tokenURI function is called.
 *      - Royalty: called when the ERC2981.royaltyInfo function is called.
 *
 *  Each of these extensions is an external call made to a contract that implements the `IHook` interface.
 *
 *  The purpose of extensions is to allow developers to extend their contract's functionality by running custom logic
 *  right before a token is minted, transferred, burned, or approved, or for returning a token's metadata or royalty info.
 *
 *  Developers can install extensions into their core contracts, and uninstall extensions at any time.
 *
 *  UPGRADEABILITY:
 *
 *  thirdweb will publish upgradeable, 'shared state' extensions for developers (see src/erc721/extensions/). These extension contracts are
 *  designed to be used by develpers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make
 *  beacon upgrades to developer contracts using these extensions.
 */
contract ERC721CoreBenchmarkTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    address public platformUser = address(0x456);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Test util
    CloneFactory public cloneFactory;

    // Target test contracts
    address public extensionProxyAddress;

    ERC721Core public erc721;
    AllowlistMintHookERC721 public simpleClaimHook;
    LazyMintHook public lazyMintHook;
    RoyaltyHook public royaltyHook;

    MockOneHookImpl public mockOneHook;
    MockFourHookImpl public mockFourHook;

    // Token claim params
    uint256 public pricePerToken = 0.1 ether;
    uint256 public availableSupply = 100;

    IERC721Hook.MintRequest public mintRequest;

    function setUp() public {
        // Setup up to enabling minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        cloneFactory = new CloneFactory();

        extensionProxyAddress = cloneFactory.deployDeterministicERC1967(
            address(new AllowlistMintHookERC721()),
            abi.encodeWithSelector(AllowlistMintHookERC721.initialize.selector, platformAdmin),
            bytes32("salt")
        );
        simpleClaimHook = AllowlistMintHookERC721(extensionProxyAddress);
        assertEq(simpleClaimHook.getNextTokenIdToMint(address(erc721)), 0);

        address lazyMintHookProxyAddress = cloneFactory.deployDeterministicERC1967(
            address(new LazyMintHook()),
            abi.encodeWithSelector(AllowlistMintHookERC721.initialize.selector, platformAdmin),
            bytes32("salt")
        );
        lazyMintHook = LazyMintHook(lazyMintHookProxyAddress);

        address royaltyHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new RoyaltyHook())));
        royaltyHook = RoyaltyHook(royaltyHookProxyAddress);

        address mockAddress = address(
            new EIP1967Proxy(
                address(new MockOneHookImpl()),
                abi.encodeWithSelector(MockOneHookImpl.initialize.selector, platformAdmin)
            )
        );
        mockOneHook = MockOneHookImpl(mockAddress);

        mockAddress = address(
            new EIP1967Proxy(
                address(new MockFourHookImpl()),
                abi.encodeWithSelector(MockFourHookImpl.initialize.selector, platformAdmin)
            )
        );
        mockFourHook = MockFourHookImpl(mockAddress);

        vm.stopPrank();

        // Developer contract: gas incurred by developer.
        vm.startPrank(platformUser);

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit;

        erc721 = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );

        vm.stopPrank();

        vm.label(address(erc721), "ERC721Core");
        vm.label(extensionProxyAddress, "AllowlistMintHookERC721");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");

        // Developer sets up token metadata and claim conditions: gas incurred by developer
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory mdata = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            mdata[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32 root = merkle.getRoot(mdata);

        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: pricePerToken,
            availableSupply: availableSupply,
            allowlistMerkleRoot: root
        });

        AllowlistMintHookERC721.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        bytes[] memory multicallDataMintHook = new bytes[](2);

        multicallDataMintHook[0] =
            abi.encodeWithSelector(AllowlistMintHookERC721.setDefaultFeeConfig.selector, feeConfig);

        multicallDataMintHook[1] = abi.encodeWithSelector(AllowlistMintHookERC721.setClaimCondition.selector, condition);

        // Developer installs `AllowlistMintHookERC721` extension
        {
            vm.startPrank(platformUser);

            erc721.installHook(
                IHookInstaller.InstallHookParams(
                    IHook(extensionProxyAddress),
                    0,
                    abi.encodeWithSelector(Multicallable.multicall.selector, multicallDataMintHook)
                )
            );
            erc721.installHook(
                IHookInstaller.InstallHookParams(
                    IHook(lazyMintHookProxyAddress),
                    0,
                    abi.encodeWithSelector(LazyMintHook.lazyMint.selector, 3, "https://example.com/", "")
                )
            );

            vm.stopPrank();
        }

        vm.deal(claimer, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY END-USER CONTRACT
    //////////////////////////////////////////////////////////////*/

    function test_deployEndUserContract() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit;

        vm.resumeGasMetering();

        ERC721Core core = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );
    }

    function test_deployEndUserContract_withHooks() public {
        // Deploy a minimal proxy to the ERC721Core implementation contract.

        vm.pauseGasMetering();

        address[] memory extensions = new address[](3);
        extensions[0] = address(simpleClaimHook);
        extensions[1] = address(lazyMintHook);
        extensions[2] = address(royaltyHook);

        ERC721Core.OnInitializeParams memory onInitializeCall;
        ERC721Core.InstallHookParams[] memory hooksToInstallOnInit = new ERC721Core.InstallHookParams[](3);

        hooksToInstallOnInit[0].hook = IHook(address(simpleClaimHook));
        hooksToInstallOnInit[1].hook = IHook(address(lazyMintHook));
        hooksToInstallOnInit[2].hook = IHook(address(royaltyHook));

        vm.resumeGasMetering();

        ERC721Core core = new ERC721Core(
            "Test ERC721",
            "TST",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            platformUser, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );
    }

    /*//////////////////////////////////////////////////////////////
                        MINT 1 TOKEN AND 10 TOKENS
    //////////////////////////////////////////////////////////////*/

    function test_mintOneToken() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC721Core claimContract = erc721;
        address claimerAddress = claimer;

        mintRequest.pricePerToken = pricePerToken;
        mintRequest.quantity = quantityToClaim;
        mintRequest.token = address(claimContract);
        mintRequest.minter = claimerAddress;
        mintRequest.allowlistProof = proofs;

        IERC721Hook.MintRequest memory req = mintRequest;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken}(req);
    }

    function test_mintTenTokens() public {
        vm.pauseGasMetering();

        // Check pre-mint state
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        uint256 quantityToClaim = 10;

        bytes memory encodedArgs = abi.encode(proofs);

        ERC721Core claimContract = erc721;
        address claimerAddress = claimer;

        mintRequest.pricePerToken = pricePerToken * 10;
        mintRequest.quantity = quantityToClaim;
        mintRequest.token = address(claimContract);
        mintRequest.minter = claimerAddress;
        mintRequest.allowlistProof = proofs;

        IERC721Hook.MintRequest memory req = mintRequest;

        vm.prank(claimerAddress);

        vm.resumeGasMetering();

        // Claim token
        claimContract.mint{value: pricePerToken * 10}(req);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER 1 TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_transferOneToken() public {
        vm.pauseGasMetering();

        // Claimer claims one token
        string[] memory claimInputs = new string[](2);
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        uint256 quantityToClaim = 1;

        bytes memory encodedArgs = abi.encode(proofs);

        mintRequest.pricePerToken = pricePerToken;
        mintRequest.quantity = quantityToClaim;
        mintRequest.token = address(erc721);
        mintRequest.minter = claimer;
        mintRequest.allowlistProof = proofs;

        IERC721Hook.MintRequest memory req = mintRequest;

        // Claim token
        vm.prank(claimer);
        erc721.mint{value: pricePerToken}(req);

        uint256 tokenId = 0;
        address to = address(0x121212);
        address from = claimer;

        ERC721Core erc721Contract = erc721;
        vm.prank(from);

        vm.resumeGasMetering();

        // Transfer token
        erc721Contract.transferFrom(from, to, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM A BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_performUpgrade() public {
        vm.pauseGasMetering();

        address newAdmin = address(0x7890);
        address newImpl = address(new AllowlistMintHookERC721());
        address currentAdmin = platformAdmin;
        UUPSUpgradeable proxy = UUPSUpgradeable(payable(extensionProxyAddress));

        vm.prank(currentAdmin);

        vm.resumeGasMetering();

        // Perform upgrade
        proxy.upgradeToAndCall(newImpl, "");
        // assertEq(ERC721Hook(address(proxy)).admin(), newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
            ADD NEW FUNCTIONALITY AND UPDATE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_installOneHook() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockOneHook);
        IHook mockHook = IHook(mockAddress);

        ERC721Core extensionConsumer = erc721;

        vm.prank(platformUser);

        vm.resumeGasMetering();

        extensionConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, bytes("")));
    }

    function test_installfiveHooks() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockFourHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core extensionConsumer = erc721;

        vm.prank(platformUser);
        extensionConsumer.uninstallHook(IHook(extensionProxyAddress));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        extensionConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, bytes("")));
    }

    function test_uninstallOneHook() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockOneHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core extensionConsumer = erc721;

        vm.prank(platformUser);
        extensionConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, bytes("")));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        extensionConsumer.uninstallHook(mockHook);
    }

    function test_uninstallFiveHooks() public {
        vm.pauseGasMetering();

        address mockAddress = address(mockFourHook);
        IHook mockHook = IHook(mockAddress);
        ERC721Core extensionConsumer = erc721;

        vm.prank(platformUser);
        extensionConsumer.uninstallHook(IHook(extensionProxyAddress));

        vm.prank(platformUser);
        extensionConsumer.installHook(IHookInstaller.InstallHookParams(mockHook, 0, bytes("")));

        vm.prank(platformUser);

        vm.resumeGasMetering();

        extensionConsumer.uninstallHook(mockHook);
    }
}
