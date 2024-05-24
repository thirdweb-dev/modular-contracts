// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "@solady/utils/ERC1967FactoryConstants.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCoreUpgradeable} from "src/ModularCoreUpgradeable.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {MintableERC20, MintableStorage} from "src/extension/token/minting/MintableERC20.sol";
import {Role} from "src/Role.sol";

contract MintableERC20Test is Test {
    ERC20Core public core;

    MintableERC20 public extensionImplementation;
    MintableERC20 public installedExtension;

    uint256 ownerPrivateKey = 1;
    address public owner;

    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;

    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient = address(0x123);

    // Signature vars
    bytes32 internal typehashMintRequest;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    MintableERC20.MintRequestERC20 public mintRequest;

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Util fn
    function signMintRequest(MintableERC20.MintRequestERC20 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest,
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
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        permissionedActor = vm.addr(permissionedActorPrivateKey);
        unpermissionedActor = vm.addr(unpermissionedActorPrivateKey);

        // Deterministic, canonical ERC1967Factory contract
        vm.etch(ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE);

        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC20Core(ERC1967FactoryConstants.ADDRESS, "test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new MintableERC20();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        IModularCore.InstalledExtension[] memory installedExtensions = core.getInstalledExtensions();
        installedExtension = MintableERC20(installedExtensions[0].implementation);

        // Setup signature vars
        typehashMintRequest = keccak256(
            "MintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
        );
        nameHash = keccak256(bytes("MintableERC20"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator =
            keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(installedExtension)));

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
        MintableERC20(address(core)).setSaleConfig(saleRecipient);

        address recipient = MintableERC20(address(core)).getSaleConfig(address(core));

        assertEq(recipient, saleRecipient);
    }

    function test_setSaleConfig_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        MintableERC20(address(core)).setSaleConfig(address(0x123));
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: beforeMintERC20
    //////////////////////////////////////////////////////////////*/

    function test_mint_state() public {
        vm.deal(tokenRecipient, 100 ether);

        MintableERC20.MintRequestERC20 memory mintRequest = MintableERC20.MintRequestERC20({
            token: address(core),
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: address(0x123),
            quantity: 100 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(mintRequest, permissionedActorPrivateKey);

        MintableERC20.MintParamsERC20 memory params = MintableERC20.MintParamsERC20(mintRequest, sig);

        uint256 balBefore = tokenRecipient.balance;
        assertEq(balBefore, 100 ether);

        vm.prank(tokenRecipient);
        core.mint{value: (mintRequest.quantity * mintRequest.pricePerUnit) / 1 ether}(
            mintRequest.recipient, mintRequest.quantity, abi.encode(params)
        );

        // Check minted balance
        assertEq(core.balanceOf(address(0x123)), 100 ether);

        assertEq(tokenRecipient.balance, balBefore - (mintRequest.quantity * mintRequest.pricePerUnit) / 1 ether);
    }

    function test_mint_revert_unableToDecodeArgs() public {}
    function test_mint_revert_requestInvalidToken() public {}
    function test_mint_revert_requestInvalidRecipient() public {}
    function test_mint_revert_requestInvalidAmount() public {}
    function test_mint_revert_requestBeforeValidityStart() public {}
    function test_mint_revert_requestAfterValidityEnd() public {}
    function test_mint_revert_requestUidReused() public {}
    function test_mint_revert_requestUnauthorizedSigner() public {}
    function test_mint_revert_noPriceButNativeTokensSent() public {}
    function test_mint_revert_incorrectNativeTokenSent() public {}
    function test_mint_revert_insufficientERC20CurrencyBalance() public {}
}
