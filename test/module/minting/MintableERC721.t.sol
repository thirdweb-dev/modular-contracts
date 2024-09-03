// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {Test} from "forge-std/Test.sol";

// Target contract

import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";

import {Role} from "src/Role.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {MintableERC721} from "src/module/token/minting/MintableERC721.sol";

contract MockCurrency is ERC20 {

    function mintTo(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return "MockCurrency";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return "MOCK";
    }

}

contract MintableERC721Test is Test {

    ERC721Core public core;

    MintableERC721 public mintableModule;
    BatchMetadataERC721 public batchMetadataModule;

    uint256 ownerPrivateKey = 1;
    address public owner;

    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;

    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient = address(0x123);
    uint256 amount = 100;
    string baseURI = "ipfs://base/";

    // Signature vars
    bytes32 internal typehashMintSignatureParams;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    MintableERC721.MintSignatureParamsERC721 public mintRequest;

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Util fn
    function signMintSignatureParams(MintableERC721.MintSignatureParamsERC721 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintSignatureParams,
            tokenRecipient,
            amount,
            keccak256(bytes(baseURI)),
            keccak256(abi.encode(_req.startTimestamp, _req.endTimestamp, _req.currency, _req.pricePerUnit, _req.uid))
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        permissionedActor = vm.addr(permissionedActorPrivateKey);
        unpermissionedActor = vm.addr(unpermissionedActorPrivateKey);

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        mintableModule = new MintableERC721();
        batchMetadataModule = new BatchMetadataERC721();

        // install module
        bytes memory encodedInstallParams = abi.encode(owner);
        vm.prank(owner);
        core.installModule(address(mintableModule), encodedInstallParams);

        bytes memory encodedBatchMetadataInstallParams = "";
        vm.prank(owner);
        core.installModule(address(batchMetadataModule), encodedBatchMetadataInstallParams);

        // Setup signature vars
        typehashMintSignatureParams =
            keccak256("MintRequestERC721(address to,uint256 amount,string baseURI,bytes data)");
        nameHash = keccak256(bytes("ERC721Core"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(core)));

        // Give permissioned actor minter role
        vm.prank(owner);
        core.grantRoles(permissionedActor, Role._MINTER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: get / set SaleConfig
    //////////////////////////////////////////////////////////////*/

    function test_saleConfig_state() public {
        address saleRecipient = address(0x123);

        vm.prank(owner);
        MintableERC721(address(core)).setSaleConfig(saleRecipient);

        address recipient = MintableERC721(address(core)).getSaleConfig();

        assertEq(recipient, saleRecipient);
    }

    function test_setSaleConfig_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintableERC721(address(core)).setSaleConfig(address(0x123));
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: beforeMintERC721
    //////////////////////////////////////////////////////////////*/

    function test_mint_state() public {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        uint256 balBefore = tokenRecipient.balance;
        assertEq(balBefore, 100 ether);
        assertEq(saleRecipient.balance, 0);

        vm.prank(tokenRecipient);
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig
        );

        // Check minted balance
        assertEq(core.balanceOf(address(0x123)), amount);

        uint256 salePrice = amount * mintRequest.pricePerUnit;
        assertEq(tokenRecipient.balance, balBefore - salePrice);
        assertEq(saleRecipient.balance, salePrice);
    }

    function test_mint_revert_unableToDecodeArgs() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert();
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(bytes("random mixer")), sig
        );
    }

    function test_mint_revert_requestBeforeValidityStart() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp + 100), // tx before validity start
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableRequestOutOfTimeWindow.selector));
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig
        );
    }

    function test_mint_revert_requestAfterValidityEnd() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200), // tx at / after validity end
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.warp(mintRequest.endTimestamp);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableRequestOutOfTimeWindow.selector));
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig
        );
    }

    function test_mint_revert_requestUidReused() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200), // tx at / after validity end
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig
        );
        assertEq(core.balanceOf(tokenRecipient), amount);

        MintableERC721.MintSignatureParamsERC721 memory mintRequestTwo = mintRequest;
        mintRequestTwo.pricePerUnit = 0;

        bytes memory sigTwo = signMintSignatureParams(mintRequestTwo, permissionedActorPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableRequestUidReused.selector));
        core.mintWithSignature(tokenRecipient, amount, baseURI, abi.encode(mintRequestTwo), sigTwo);
    }

    function test_mint_revert_requestUnauthorizedSigner() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, ownerPrivateKey); // is owner but not MINTER_ROLE holder

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableSignatureMintUnauthorized.selector));
        core.mintWithSignature{value: amount * mintRequest.pricePerUnit}(
            tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig
        );
    }

    function test_mint_revert_noPriceButNativeTokensSent() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: 1 ether}(tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig);
    }

    function test_mint_revert_incorrectNativeTokenSent() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(MintableERC721.MintableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: 1 ether}(tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig);
    }

    function test_mint_revert_insufficientERC721CurrencyBalance() public {
        MockCurrency currency = new MockCurrency();

        assertEq(currency.balanceOf(tokenRecipient), 0);

        MintableERC721.MintSignatureParamsERC721 memory mintRequest = MintableERC721.MintSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: address(currency),
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintSignatureParams(mintRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(0x7939f424)); // TransferFromFailed()
        core.mintWithSignature(tokenRecipient, amount, baseURI, abi.encode(mintRequest), sig);
    }

}
