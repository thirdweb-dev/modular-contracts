// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "@murky/Merkle.sol";

import {MintHook} from "src/minting/MintHook.sol";

import {IHook} from "@core-contracts/interface/IHook.sol";
import {IHookInstaller} from "@core-contracts/interface/IHookInstaller.sol";
import {ERC20Core} from "@core-contracts/core/token/ERC20Core.sol";
import {ERC721Core} from "@core-contracts/core/token/ERC721Core.sol";
import {ERC1155Core} from "@core-contracts/core/token/ERC1155Core.sol";

contract MintHookBenchmarkTest is Test {
    // Target test contracts
    MintHook public hook;
    ERC20Core public erc20Core;
    ERC721Core public erc721Core;
    ERC1155Core public erc1155Core;

    // Contract admin
    uint256 adminPrivateKey = 100;
    address public admin;

    // Allowlist claim params
    address allowlistedClaimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
    bytes32 public allowlistRoot;
    bytes32[] public allowlistProof;

    // Signature mint params
    bytes32 hookDomainSeparator;
    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC20 = keccak256(
        "SignatureMintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );
    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC721 = keccak256(
        "SignatureMintRequestERC721(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );
    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC1155 = keccak256(
        "SignatureMintRequestERC1155(uint256 tokenId,address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    // Common test params
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        admin = vm.addr(adminPrivateKey);

        hook = new MintHook();

        IHookInstaller.OnInitializeParams memory onInitializeCall;
        IHookInstaller.InstallHookParams[] memory hooksToInstallOnInit = new IHookInstaller.InstallHookParams[](0);

        erc20Core = new ERC20Core(
            "ERC20 Token",
            "ERC20",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            admin,
            onInitializeCall,
            hooksToInstallOnInit
        );

        erc721Core = new ERC721Core(
            "ERC721 Token",
            "ERC721",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            admin,
            onInitializeCall,
            hooksToInstallOnInit
        );

        erc1155Core = new ERC1155Core(
            "ERC1155 Token",
            "ERC1155",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            admin,
            onInitializeCall,
            hooksToInstallOnInit
        );

        // Setup domain separator
        bytes32 nameHash = keccak256(bytes("MintHook"));
        bytes32 versionHash = keccak256(bytes("1"));
        bytes32 typehashEip712 =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        hookDomainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(hook)));

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

        // Install hook and set sale recipient
        IHookInstaller.InstallHookParams memory installHookParams = IHookInstaller.InstallHookParams(
            IHook(address(hook)), 0, abi.encodeWithSelector(hook.setSaleConfig.selector, admin, address(0x123), 100)
        );

        vm.startPrank(admin);
        erc20Core.installHook(installHookParams);
        erc721Core.installHook(installHookParams);
        erc1155Core.installHook(installHookParams);
        vm.stopPrank();
    }

    function _signMintRequestERC20(MintHook.SignatureMintRequestERC20 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            TYPEHASH_SIGNATURE_MINT_ERC20,
            _req.token,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            _req.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", hookDomainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function _signMintRequestERC721(MintHook.SignatureMintRequestERC721 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            TYPEHASH_SIGNATURE_MINT_ERC721,
            _req.token,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            _req.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", hookDomainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function _signMintRequestERC1155(MintHook.SignatureMintRequestERC1155 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            TYPEHASH_SIGNATURE_MINT_ERC1155,
            _req.tokenId,
            _req.token,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            _req.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", hookDomainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function testBenchmarkSignatureMintERC20() public {
        vm.pauseGasMetering();

        MintHook.SignatureMintRequestERC20 memory request = MintHook.SignatureMintRequestERC20({
            token: address(erc20Core),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: allowlistedClaimer,
            quantity: 10 ether,
            currency: address(NATIVE_TOKEN),
            pricePerUnit: 0.1 ether,
            uid: bytes32("UID")
        });
        bytes memory signature = _signMintRequestERC20(request, adminPrivateKey);
        MintHook.SignatureMintParamsERC20 memory params =
            MintHook.SignatureMintParamsERC20({request: request, signature: signature});
        bytes memory data = abi.encode(params);

        address to = request.recipient;
        uint256 quantity = request.quantity;
        ERC20Core core = erc20Core;

        vm.deal(address(this), 1 ether);

        vm.resumeGasMetering();

        core.mint{value: 1 ether}(to, quantity, data);
    }

    function testBenchmarkSignatureMintERC721() public {
        vm.pauseGasMetering();

        MintHook.SignatureMintRequestERC721 memory request = MintHook.SignatureMintRequestERC721({
            token: address(erc721Core),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: allowlistedClaimer,
            quantity: 1,
            currency: address(NATIVE_TOKEN),
            pricePerUnit: 0.1 ether,
            uid: bytes32("UID")
        });
        bytes memory signature = _signMintRequestERC721(request, adminPrivateKey);
        MintHook.SignatureMintParamsERC721 memory params =
            MintHook.SignatureMintParamsERC721({request: request, signature: signature});

        bytes memory data = abi.encode(params);

        address to = request.recipient;
        uint256 quantity = request.quantity;
        ERC721Core core = erc721Core;

        vm.deal(address(this), 0.1 ether);

        vm.resumeGasMetering();

        core.mint{value: 0.1 ether}(to, quantity, data);
    }

    function testBenchmarkSignatureMintERC1155() public {
        vm.pauseGasMetering();

        uint256 tokenId = 0;

        MintHook.SignatureMintRequestERC1155 memory request = MintHook.SignatureMintRequestERC1155({
            tokenId: tokenId,
            token: address(erc1155Core),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: allowlistedClaimer,
            quantity: 1,
            currency: address(NATIVE_TOKEN),
            pricePerUnit: 0.1 ether,
            uid: bytes32("UID")
        });
        bytes memory signature = _signMintRequestERC1155(request, adminPrivateKey);
        MintHook.SignatureMintParamsERC1155 memory params =
            MintHook.SignatureMintParamsERC1155({request: request, signature: signature});

        bytes memory data = abi.encode(params);

        address to = request.recipient;
        uint256 quantity = request.quantity;
        ERC1155Core core = erc1155Core;

        vm.deal(address(this), 0.1 ether);

        vm.resumeGasMetering();

        core.mint{value: 0.1 ether}(to, tokenId, quantity, data);
    }

    function testBenchmarkClaimERC20() public {
        vm.pauseGasMetering();

        MintHook.ClaimPhase memory phase = MintHook.ClaimPhase({
            availableSupply: 100 ether,
            allowlistMerkleRoot: allowlistRoot,
            pricePerUnit: 0.1 ether,
            currency: address(NATIVE_TOKEN),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100)
        });

        vm.prank(admin);
        MintHook(address(erc20Core)).setClaimPhaseERC20(phase);

        address to = allowlistedClaimer;
        uint256 quantity = 10 ether;
        bytes memory data = abi.encode(
            MintHook.ClaimParams({
                allowlistProof: allowlistProof,
                expectedCurrency: address(NATIVE_TOKEN),
                expectedPricePerUnit: 0.1 ether
            })
        );

        ERC20Core core = erc20Core;

        vm.deal(address(this), 1 ether);

        vm.resumeGasMetering();

        core.mint{value: 1 ether}(to, quantity, data);
    }

    function testBenchmarkClaimERC721() public {
        vm.pauseGasMetering();

        MintHook.ClaimPhase memory phase = MintHook.ClaimPhase({
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot,
            pricePerUnit: 0.1 ether,
            currency: address(NATIVE_TOKEN),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100)
        });

        vm.prank(admin);
        MintHook(address(erc721Core)).setClaimPhaseERC721(phase);

        address to = allowlistedClaimer;
        uint256 quantity = 1;
        bytes memory data = abi.encode(
            MintHook.ClaimParams({
                allowlistProof: allowlistProof,
                expectedCurrency: address(NATIVE_TOKEN),
                expectedPricePerUnit: 0.1 ether
            })
        );

        ERC721Core core = erc721Core;

        vm.deal(address(this), 1 ether);

        vm.resumeGasMetering();

        core.mint{value: 0.1 ether}(to, quantity, data);
    }

    function testBenchmarkClaimERC1155() public {
        vm.pauseGasMetering();

        uint256 tokenId = 0;

        MintHook.ClaimPhase memory phase = MintHook.ClaimPhase({
            availableSupply: 100,
            allowlistMerkleRoot: allowlistRoot,
            pricePerUnit: 0.1 ether,
            currency: address(NATIVE_TOKEN),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100)
        });

        vm.prank(admin);
        MintHook(address(erc1155Core)).setClaimPhaseERC1155(tokenId, phase);

        address to = allowlistedClaimer;
        uint256 quantity = 1;
        bytes memory data = abi.encode(
            MintHook.ClaimParams({
                allowlistProof: allowlistProof,
                expectedCurrency: address(NATIVE_TOKEN),
                expectedPricePerUnit: 0.1 ether
            })
        );

        ERC1155Core core = erc1155Core;

        vm.deal(address(this), 1 ether);

        vm.resumeGasMetering();

        core.mint{value: 0.1 ether}(to, tokenId, quantity, data);
    }
}
