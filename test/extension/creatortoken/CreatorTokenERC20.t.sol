// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";

import "./CreatorTokenUtils.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {CreatorTokenERC20} from "src/extension/token/creatortoken/CreatorTokenERC20.sol";
import {MintableERC20} from "src/extension/token/minting/MintableERC20.sol";
import {Role} from "src/Role.sol";

contract CreatorTokenERC20Ext is CreatorTokenERC20 {}

contract TransferToken {
    function transferToken(address payable tokenContract, address from, address to, uint256 amount) public {
        ERC20Core(tokenContract).transferFrom(from, to, amount);
    }
}

contract CreatorTokenERC20Test is Test {
    ERC20Core public core;

    CreatorTokenERC20Ext public extensionImplementation;

    MintableERC20 public mintableExtensionImplementation;

    TransferToken public transferTokenContract;

    ITransferValidator public mockTransferValidator;

    uint256 ownerPrivateKey = 1;
    address public owner;
    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;
    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient = address(0x123);

    bytes32 internal typehashMintRequest;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    MintableERC20.MintRequestERC20 public mintRequest;

    bytes32 internal evmVersionHash;

    function signMintRequest(MintableERC20.MintRequestERC20 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest,
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

        evmVersionHash = _checkEVMVersion();

        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC20Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new CreatorTokenERC20Ext();
        mintableExtensionImplementation = new MintableERC20();

        transferTokenContract = new TransferToken();

        // install extension
        vm.startPrank(owner);
        core.installExtension(address(extensionImplementation), "");
        core.installExtension(address(mintableExtensionImplementation), "");
        vm.stopPrank();

        typehashMintRequest = keccak256(
            "MintRequestERC20(uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
        );
        nameHash = keccak256(bytes("MintableERC20"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(core)));

        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);

        mockTransferValidator = ITransferValidator(0x721C0078c2328597Ca70F5451ffF5A7B38D4E947);
        vm.etch(address(mockTransferValidator), TRANSFER_VALIDATOR_DEPLOYED_BYTECODE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferValidator() public {
        assertEq(CreatorTokenERC20(address(core)).getTransferValidator(), address(0));

        // set transfer validator
        vm.prank(owner);
        CreatorTokenERC20(address(core)).setTransferValidator(address(mockTransferValidator));
        assertEq(CreatorTokenERC20(address(core)).getTransferValidator(), address(mockTransferValidator));

        // set transfer validator back to zero address
        vm.prank(owner);
        CreatorTokenERC20(address(core)).setTransferValidator(address(0));
        assertEq(CreatorTokenERC20(address(core)).getTransferValidator(), address(0));
    }

    function test_revert_setTransferValidator_accessControl() public {
        // attemp to set the transfer validator from an unpermissioned actor
        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        CreatorTokenERC20(address(core)).setTransferValidator(address(mockTransferValidator));
    }

    function test_revert_setTransferValidator_invalidContract() public {
        // attempt to set the transfer validator to an invalid contract
        vm.prank(owner);
        vm.expectRevert(CreatorTokenERC20.InvalidTransferValidatorContract.selector);
        CreatorTokenERC20(address(core)).setTransferValidator(address(11111));
    }

    function test_allowsTransferWithTransferValidatorAddressZero() public {
        _mintToken(owner, 1);

        assertEq(1, core.balanceOf(owner));

        vm.prank(owner);
        core.approve(address(transferTokenContract), 1);

        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 1);

        assertEq(1, core.balanceOf(permissionedActor));
    }

    function test_transferRestrictedWithValidValidator() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }
        _mintToken(owner, 1);

        assertEq(1, core.balanceOf(owner));

        // set transfer validator
        vm.prank(owner);
        CreatorTokenERC20(address(core)).setTransferValidator(address(mockTransferValidator));

        // attempt to transfer token from owner to permissionedActor
        vm.prank(owner);
        core.approve(address(transferTokenContract), 1);

        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 1);

        assertEq(0, core.balanceOf(permissionedActor));
    }

    function _mintToken(address to, uint256 quantity) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC20(address(core)).setSaleConfig(saleRecipient);

        MintableERC20.MintRequestERC20 memory mintRequest = MintableERC20.MintRequestERC20({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: to,
            quantity: quantity,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(mintRequest, ownerPrivateKey);

        MintableERC20.MintParamsERC20 memory params = MintableERC20.MintParamsERC20(mintRequest, sig);

        vm.prank(owner);
        core.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
            mintRequest.recipient, mintRequest.quantity, abi.encode(params)
        );
    }

    function _checkEVMVersion() internal returns (bytes32 evmVersionHash) {
        string memory path = "foundry.toml";
        string memory file;
        for (uint256 i = 0; i < 100; i++) {
            file = vm.readLine(path);
            if (bytes(file).length == 0) {
                break;
            }
            if (
                keccak256(abi.encode(file)) == keccak256(abi.encode('evm_version = "cancun"'))
                    || keccak256(abi.encode(file)) == keccak256(abi.encode('evm_version = "london"'))
                    || keccak256(abi.encode(file)) == keccak256(abi.encode('evm_version = "paris"'))
                    || keccak256(abi.encode(file)) == keccak256(abi.encode('evm_version = "shanghai"'))
            ) {
                break;
            }
        }

        evmVersionHash = keccak256(abi.encode(file));
    }
}
