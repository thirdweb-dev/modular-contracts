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
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {CreatorTokenERC1155} from "src/extension/token/creatortoken/CreatorTokenERC1155.sol";
import {MintableERC1155} from "src/extension/token/minting/MintableERC1155.sol";
import {Role} from "src/Role.sol";

contract CreatorTokenERC1155Ext is CreatorTokenERC1155 {}

contract TransferToken {
    function transferToken(address payable tokenContract, address from, address to, uint256 tokenId, uint256 value)
        public
    {
        ERC1155Core(tokenContract).safeTransferFrom(from, to, tokenId, value, "");
    }

    function batchTransferToken(
        address payable tokenContract,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory values
    ) public {
        ERC1155Core(tokenContract).safeBatchTransferFrom(from, to, tokenIds, values, "");
    }
}

contract CreatorTokenERC1155Test is Test {
    ERC1155Core public core;

    CreatorTokenERC1155Ext public extensionImplementation;

    MintableERC1155 public mintableExtensionImplementation;

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

    MintableERC1155.MintRequestERC1155 public mintRequest;

    bytes32 internal evmVersionHash;

    function signMintRequest(MintableERC1155.MintRequestERC1155 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest,
            _req.tokenId,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            keccak256(bytes(_req.metadataURI)),
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

        core = new ERC1155Core("test", "TEST", "", owner, extensions, extensionData);
        extensionImplementation = new CreatorTokenERC1155Ext();
        mintableExtensionImplementation = new MintableERC1155();

        transferTokenContract = new TransferToken();

        // install extension
        vm.startPrank(owner);
        core.installExtension(address(extensionImplementation), "");
        core.installExtension(address(mintableExtensionImplementation), "");
        vm.stopPrank();

        typehashMintRequest = keccak256(
            "MintRequestERC1155(uint256 tokenId,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,string metadataURI,bytes32 uid)"
        );
        nameHash = keccak256(bytes("MintableERC1155"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(core)));

        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);

        // set up transfer validator
        mockTransferValidator = ITransferValidator(0x721C0078c2328597Ca70F5451ffF5A7B38D4E947);
        vm.etch(address(mockTransferValidator), TRANSFER_VALIDATOR_DEPLOYED_BYTECODE);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferValidator() public {
        assertEq(CreatorTokenERC1155(address(core)).getTransferValidator(), address(0));

        // set transfer validator
        vm.prank(owner);
        CreatorTokenERC1155(address(core)).setTransferValidator(address(mockTransferValidator));
        assertEq(CreatorTokenERC1155(address(core)).getTransferValidator(), address(mockTransferValidator));

        // set transfer validator back to zero address
        vm.prank(owner);
        CreatorTokenERC1155(address(core)).setTransferValidator(address(0));
        assertEq(CreatorTokenERC1155(address(core)).getTransferValidator(), address(0));
    }

    function test_revert_setTransferValidator_accessControl() public {
        // attemp to set the transfer validator from an unpermissioned actor
        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        CreatorTokenERC1155(address(core)).setTransferValidator(address(mockTransferValidator));
    }

    function test_revert_setTransferValidator_invalidContract() public {
        // attempt to set the transfer validator to an invalid contract
        vm.prank(owner);
        vm.expectRevert(CreatorTokenERC1155.InvalidTransferValidatorContract.selector);
        CreatorTokenERC1155(address(core)).setTransferValidator(address(11111));
    }

    function test_allowsTransferWithTransferValidatorAddressZero() public {
        _mintToken(owner, 2, 0, bytes32("1"));
        _mintToken(owner, 1, 1, bytes32("2"));

        assertEq(2, core.balanceOf(owner, 0));
        assertEq(1, core.balanceOf(owner, 1));

        vm.prank(owner);
        core.setApprovalForAll(address(transferTokenContract), true);

        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 0, 1);

        assertEq(1, core.balanceOf(permissionedActor, 0));

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;

        transferTokenContract.batchTransferToken(payable(address(core)), owner, permissionedActor, tokenIds, values);

        assertEq(2, core.balanceOf(permissionedActor, 0));
        assertEq(1, core.balanceOf(permissionedActor, 1));
    }

    function test_transferRestrictedWithValidValidator() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }

        _mintToken(owner, 2, 0, bytes32("1"));
        _mintToken(owner, 1, 1, bytes32("2"));

        assertEq(2, core.balanceOf(owner, 0));
        assertEq(1, core.balanceOf(owner, 1));

        // set transfer validator
        vm.prank(owner);
        CreatorTokenERC1155(address(core)).setTransferValidator(address(mockTransferValidator));

        // attempt to transfer token from owner to permissionedActor
        vm.prank(owner);
        core.setApprovalForAll(address(transferTokenContract), true);

        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 0, 1);

        assertEq(0, core.balanceOf(permissionedActor, 0));

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;

        vm.expectRevert(0xef28f901);
        transferTokenContract.batchTransferToken(payable(address(core)), owner, permissionedActor, tokenIds, values);

        assertEq(0, core.balanceOf(permissionedActor, 0));
        assertEq(0, core.balanceOf(permissionedActor, 1));
    }

    function _mintToken(address to, uint256 quantity, uint256 id, bytes32 uid) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC1155(address(core)).setSaleConfig(saleRecipient);

        MintableERC1155.MintRequestERC1155 memory mintRequest = MintableERC1155.MintRequestERC1155({
            tokenId: id,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: to,
            quantity: quantity,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: uid,
            metadataURI: "https://example.com/"
        });
        bytes memory sig = signMintRequest(mintRequest, ownerPrivateKey);

        MintableERC1155.MintParamsERC1155 memory params = MintableERC1155.MintParamsERC1155(mintRequest, sig, "");

        vm.prank(owner);
        core.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
            mintRequest.recipient, mintRequest.tokenId, mintRequest.quantity, abi.encode(params)
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
