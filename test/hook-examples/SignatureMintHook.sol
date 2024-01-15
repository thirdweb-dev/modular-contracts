// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CloneFactory} from "src/infra/CloneFactory.sol";
import {MinimalUpgradeableRouter} from "src/infra/MinimalUpgradeableRouter.sol";

import {SignatureMintHook} from "src/erc721/hooks/SignatureMintHook.sol";
import {LazyMintMetadataHook} from "src/erc721/hooks/LazyMintMetadataHook.sol";
import {SimpleDistributeHook} from "src/erc721/hooks/SimpleDistributeHook.sol";
import {RoyaltyHook} from "src/erc721/hooks/RoyaltyHook.sol";

import {ERC721Core, ERC721Initializable} from "src/erc721/ERC721Core.sol";
import {IERC721} from "src/interface/erc721/IERC721.sol";
import {IHook} from "src/interface/extension/IHook.sol";

contract SignatureMintHookTest is Test {
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    // Participants
    address public platformAdmin = address(0x123);
    uint256 platformUserPkey = 100;
    address public platformUser;
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Target test contracts
    ERC721Core public erc721;
    SignatureMintHook public sigmintHook;
    LazyMintMetadataHook public lazyMintHook;
    RoyaltyHook public royaltyHook;
    SimpleDistributeHook public distributeHook;

    // Signature mint params
    bytes32 internal typehashMintRequest;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    function setUp() public {
        platformUser = vm.addr(platformUserPkey);

        // Setup up to enabling minting on ERC-721 contract.

        // Platform contracts: gas incurred by platform.
        vm.startPrank(platformAdmin);

        CloneFactory cloneFactory = new CloneFactory();

        address sigmintHookProxyAddress =
            address(new MinimalUpgradeableRouter(platformAdmin, address(new SignatureMintHook())));
        sigmintHook = SignatureMintHook(sigmintHookProxyAddress);
        assertEq(sigmintHook.getNextTokenIdToMint(address(erc721)), 0);

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
        vm.label(address(sigmintHook), "SignatureMintHook");
        vm.label(address(lazyMintHook), "LazyMintHook");
        vm.label(address(royaltyHook), "RoyaltyHook");
        vm.label(platformAdmin, "Admin");
        vm.label(platformUser, "Developer");
        vm.label(claimer, "Claimer");

        // Setup signature minting params
        typehashMintRequest = keccak256(
            "MintRequest(address token,address to,uint256 quantity,uint256 pricePerToken,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );
        nameHash = keccak256(bytes("SignatureMintERC721"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator =
            keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(sigmintHook)));
    }

    function _signMintRequest(SignatureMintHook.MintRequestERC721 memory mintrequest, uint256 privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest,
            mintrequest.token,
            mintrequest.to,
            mintrequest.quantity,
            mintrequest.pricePerToken,
            mintrequest.currency,
            mintrequest.validityStartTimestamp,
            mintrequest.validityEndTimestamp,
            mintrequest.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, typedDataHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return signature;
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

        // [3] Developer: sets fee config on distribute hook
        SimpleDistributeHook.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = platformUser;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        vm.prank(platformUser);
        distributeHook.setFeeConfig(address(erc721), feeConfig);

        // [4] Developer: installs hooks in ERC-721 contract

        vm.startPrank(platformUser);

        erc721.installHook(IHook(address(sigmintHook)));
        erc721.installHook(IHook(address(lazyMintHook)));
        erc721.installHook(IHook(address(royaltyHook)));
        erc721.installHook(IHook(address(distributeHook)));

        vm.stopPrank();

        // [5] Claimer: claims a token with signature generated by developer
        vm.deal(claimer, 0.1 ether);

        SignatureMintHook.MintRequestERC721 memory mintRequest;
        mintRequest.token = address(erc721);
        mintRequest.to = claimer;
        mintRequest.quantity = 1;
        mintRequest.pricePerToken = 0.1 ether;
        mintRequest.currency = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        mintRequest.validityStartTimestamp = 0;
        mintRequest.validityEndTimestamp = 10000;
        mintRequest.uid = bytes32("random");

        bytes memory signature = _signMintRequest(mintRequest, platformUserPkey);
        bytes memory encodedArgs = abi.encode(mintRequest, signature);

        (bool success, address signer) = sigmintHook.verify(address(erc721), mintRequest, signature);
        assertEq(success, true);
        assertEq(signer, platformUser);

        vm.prank(claimer);
        erc721.mint{value: 0.1 ether}(claimer, mintRequest.quantity, encodedArgs);

        assertEq(erc721.balanceOf(claimer), 1);
        assertEq(erc721.ownerOf(0), claimer);
        assertEq(erc721.totalSupply(), 1);
        assertEq(sigmintHook.getNextTokenIdToMint(address(erc721)), 1);
    }
}
