// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";

import "test/utils/CreatorTokenUtils.sol";

// Target contract
import {IExtensionConfig} from "src/interface/IExtensionConfig.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {ModularExtension} from "src/ModularExtension.sol";
import {ModularCore} from "src/ModularCore.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {MintableERC721} from "src/extension/token/minting/MintableERC721.sol";
import {MintableERC20} from "src/extension/token/minting/MintableERC20.sol";
import {MintableERC1155} from "src/extension/token/minting/MintableERC1155.sol";

import {Role} from "src/Role.sol";
import {CreatorToken} from "src/core/token/CreatorToken/CreatorToken.sol";

contract TransferToken {
    function transferToken721(address payable tokenContract, address from, address to, uint256 tokenId) public {
        ERC721Core(tokenContract).transferFrom(from, to, tokenId);
    }

    function transferToken1155(address payable tokenContract, address from, address to, uint256 tokenId, uint256 amount)
        public
    {
        ERC1155Core(tokenContract).safeTransferFrom(from, to, tokenId, amount, "");
    }

    function batchTransferToken1155(
        address payable tokenContract,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) public {
        ERC1155Core(tokenContract).safeBatchTransferFrom(from, to, tokenIds, amounts, "");
    }

    function transferToken20(address payable tokenContract, address from, address to, uint256 amount) public {
        ERC20Core(tokenContract).transferFrom(from, to, amount);
    }
}

contract CreatorTokenERC721Test is Test {
    ERC721Core public core721;
    ERC1155Core public core1155;
    ERC20Core public core20;

    MintableERC721 public mintableExtensionImplementation;
    MintableERC1155 public mintableExtensionImplementation1155;
    MintableERC20 public mintableExtensionImplementation20;

    TransferToken public transferTokenContract;

    ITransferValidator public mockTransferValidator;

    uint256 ownerPrivateKey = 1;
    address public owner;
    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;
    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient = address(0x123);

    bytes32 internal typehashMintRequest721;
    bytes32 internal typehashMintRequest1155;
    bytes32 internal typehashMintRequest20;

    bytes32 internal nameHash721;
    bytes32 internal nameHash1155;
    bytes32 internal nameHash20;

    bytes32 internal versionHash;
    bytes32 internal typehashEip712;

    bytes32 internal domainSeparator721;
    bytes32 internal domainSeparator1155;
    bytes32 internal domainSeparator20;

    bytes32 internal evmVersionHash;

    MintableERC721.MintRequestERC721 public mintRequest;

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function signMintRequest721(MintableERC721.MintRequestERC721 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest721,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            keccak256(bytes(_req.baseURI)),
            _req.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator721, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function signMintRequest1155(MintableERC1155.MintRequestERC1155 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest1155,
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
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator1155, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, typedDataHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        return sig;
    }

    function signMintRequest20(MintableERC20.MintRequestERC20 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintRequest20,
            _req.startTimestamp,
            _req.endTimestamp,
            _req.recipient,
            _req.quantity,
            _req.currency,
            _req.pricePerUnit,
            _req.uid
        );
        bytes32 structHash = keccak256(encodedRequest);
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator20, structHash));

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

        core721 = new ERC721Core("test", "TEST", "", owner, extensions, extensionData);
        mintableExtensionImplementation = new MintableERC721();

        core1155 = new ERC1155Core("test", "TEST", "", owner, extensions, extensionData);
        mintableExtensionImplementation1155 = new MintableERC1155();

        core20 = new ERC20Core("test", "TEST", "", owner, extensions, extensionData);
        mintableExtensionImplementation20 = new MintableERC20();

        transferTokenContract = new TransferToken();

        // install extension
        vm.startPrank(owner);
        core721.installExtension(address(mintableExtensionImplementation), "");
        core1155.installExtension(address(mintableExtensionImplementation1155), "");
        core20.installExtension(address(mintableExtensionImplementation20), "");
        vm.stopPrank();

        typehashMintRequest721 = keccak256(
            "MintRequestERC721(uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,string baseURI,bytes32 uid)"
        );
        typehashMintRequest1155 = keccak256(
            "MintRequestERC1155(uint256 tokenId,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,string metadataURI,bytes32 uid)"
        );
        typehashMintRequest20 = keccak256(
            "MintRequestERC20(uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
        );

        nameHash721 = keccak256(bytes("MintableERC721"));
        nameHash1155 = keccak256(bytes("MintableERC1155"));
        nameHash20 = keccak256(bytes("MintableERC20"));

        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        domainSeparator721 =
            keccak256(abi.encode(typehashEip712, nameHash721, versionHash, block.chainid, address(core721)));
        domainSeparator1155 =
            keccak256(abi.encode(typehashEip712, nameHash1155, versionHash, block.chainid, address(core1155)));
        domainSeparator20 =
            keccak256(abi.encode(typehashEip712, nameHash20, versionHash, block.chainid, address(core20)));

        vm.startPrank(owner);
        core721.grantRoles(owner, Role._MINTER_ROLE);
        core1155.grantRoles(owner, Role._MINTER_ROLE);
        core20.grantRoles(owner, Role._MINTER_ROLE);
        vm.stopPrank();

        mockTransferValidator = ITransferValidator(0x721C0078c2328597Ca70F5451ffF5A7B38D4E947);
        vm.etch(address(mockTransferValidator), TRANSFER_VALIDATOR_DEPLOYED_BYTECODE);
    }

    function test_state_setTransferValidator() public {
        assertEq(core721.getTransferValidator(), address(0));

        // set transfer validator
        vm.startPrank(owner);
        core721.setTransferValidator(address(mockTransferValidator));
        core1155.setTransferValidator(address(mockTransferValidator));
        core20.setTransferValidator(address(mockTransferValidator));

        assertEq(core721.getTransferValidator(), address(mockTransferValidator));
        assertEq(core1155.getTransferValidator(), address(mockTransferValidator));
        assertEq(core20.getTransferValidator(), address(mockTransferValidator));

        // set transfer validator back to zero address
        core721.setTransferValidator(address(0));
        core1155.setTransferValidator(address(0));
        core20.setTransferValidator(address(0));

        assertEq(core721.getTransferValidator(), address(0));
        assertEq(core1155.getTransferValidator(), address(0));
        assertEq(core20.getTransferValidator(), address(0));
    }

    function test_revert_setTransferValidator_accessControl() public {
        // attemp to set the transfer validator from an unpermissioned actor
        vm.startPrank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        core721.setTransferValidator(address(mockTransferValidator));
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        core1155.setTransferValidator(address(mockTransferValidator));
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        core20.setTransferValidator(address(mockTransferValidator));
    }

    function test_revert_setTransferValidator_invalidContract() public {
        // attempt to set the transfer validator to an invalid contract
        vm.startPrank(owner);
        vm.expectRevert(CreatorToken.InvalidTransferValidatorContract.selector);
        core721.setTransferValidator(address(11111));
        vm.expectRevert(CreatorToken.InvalidTransferValidatorContract.selector);
        core1155.setTransferValidator(address(11111));
        vm.expectRevert(CreatorToken.InvalidTransferValidatorContract.selector);
        core20.setTransferValidator(address(11111));
    }

    function test_allowsTransferWithTransferValidatorAddressZero() public {
        _mintToken721(owner, 1);
        _mintToken1155(owner, 2, 0, bytes32("1"));
        _mintToken1155(owner, 1, 1, bytes32("2"));
        _mintToken20(owner, 1);

        assertEq(owner, core721.ownerOf(0));

        vm.startPrank(owner);
        core721.setApprovalForAll(address(transferTokenContract), true);
        core1155.setApprovalForAll(address(transferTokenContract), true);
        core20.approve(address(transferTokenContract), 1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        transferTokenContract.transferToken721(payable(address(core721)), owner, permissionedActor, 0);
        transferTokenContract.transferToken1155(payable(address(core1155)), owner, permissionedActor, 0, 1);
        transferTokenContract.transferToken20(payable(address(core20)), owner, permissionedActor, 1);
        transferTokenContract.batchTransferToken1155(
            payable(address(core1155)), owner, permissionedActor, tokenIds, amounts
        );

        assertEq(permissionedActor, core721.ownerOf(0));
        assertEq(2, core1155.balanceOf(permissionedActor, 0));
        assertEq(1, core1155.balanceOf(permissionedActor, 1));
        assertEq(1, core20.balanceOf(permissionedActor));
    }

    function test_transferRestrictedWithValidValidator() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }
        _mintToken721(owner, 1);
        _mintToken1155(owner, 2, 0, bytes32("1"));
        _mintToken1155(owner, 1, 1, bytes32("2"));
        _mintToken20(owner, 1);

        assertEq(owner, core721.ownerOf(0));

        // set transfer validator
        vm.startPrank(owner);
        core721.setTransferValidator(address(mockTransferValidator));
        core1155.setTransferValidator(address(mockTransferValidator));
        core20.setTransferValidator(address(mockTransferValidator));

        // attempt to transfer token from owner to permissionedActor
        core721.setApprovalForAll(address(transferTokenContract), true);
        core1155.setApprovalForAll(address(transferTokenContract), true);
        core20.approve(address(transferTokenContract), 1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken721(payable(address(core721)), owner, permissionedActor, 0);
        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken1155(payable(address(core1155)), owner, permissionedActor, 0, 1);
        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken20(payable(address(core20)), owner, permissionedActor, 1);
        vm.expectRevert(0xef28f901);
        transferTokenContract.batchTransferToken1155(
            payable(address(core1155)), owner, permissionedActor, tokenIds, amounts
        );

        assertEq(owner, core721.ownerOf(0));
        assertEq(0, core1155.balanceOf(permissionedActor, 0));
        assertEq(0, core1155.balanceOf(permissionedActor, 1));
        assertEq(0, core20.balanceOf(permissionedActor));
    }

    function _mintToken721(address to, uint256 quantity) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC721(address(core721)).setSaleConfig(saleRecipient);

        MintableERC721.MintRequestERC721 memory mintRequest = MintableERC721.MintRequestERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: to,
            quantity: quantity,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: bytes32("1"),
            baseURI: "https://example.com/"
        });
        bytes memory sig = signMintRequest721(mintRequest, ownerPrivateKey);

        MintableERC721.MintParamsERC721 memory params = MintableERC721.MintParamsERC721(mintRequest, sig, "");

        vm.prank(owner);
        core721.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
            mintRequest.recipient, mintRequest.quantity, abi.encode(params)
        );
    }

    function _mintToken1155(address to, uint256 quantity, uint256 id, bytes32 uid) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC1155(address(core1155)).setSaleConfig(saleRecipient);

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
        bytes memory sig = signMintRequest1155(mintRequest, ownerPrivateKey);

        MintableERC1155.MintParamsERC1155 memory params = MintableERC1155.MintParamsERC1155(mintRequest, sig, "");

        vm.prank(owner);
        core1155.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
            mintRequest.recipient, mintRequest.tokenId, mintRequest.quantity, abi.encode(params)
        );
    }

    function _mintToken20(address to, uint256 quantity) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC20(address(core20)).setSaleConfig(saleRecipient);

        MintableERC20.MintRequestERC20 memory mintRequest = MintableERC20.MintRequestERC20({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: to,
            quantity: quantity,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest20(mintRequest, ownerPrivateKey);

        MintableERC20.MintParamsERC20 memory params = MintableERC20.MintParamsERC20(mintRequest, sig);

        vm.prank(owner);
        core20.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
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
