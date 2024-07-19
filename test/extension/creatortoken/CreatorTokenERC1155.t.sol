// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

import {CreatorTokenTransferValidator} from
    "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidator.sol";
import {CreatorTokenTransferValidatorConfiguration} from
    "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidatorConfiguration.sol";
import "@limitbreak/creator-token-standards/utils/EOARegistry.sol";

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
}

contract CreatorTokenERC1155Test is Test {
    ERC1155Core public core;

    CreatorTokenERC1155Ext public extensionImplementation;

    MintableERC1155 public mintableExtensionImplementation;

    TransferToken public transferTokenContract;

    EOARegistry public eoaRegistry;
    CreatorTokenTransferValidator public mockTransferValidator;
    CreatorTokenTransferValidatorConfiguration public validatorConfiguration;

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

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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
        eoaRegistry = new EOARegistry();
        validatorConfiguration = new CreatorTokenTransferValidatorConfiguration(address(this));
        validatorConfiguration.setNativeValueToCheckPauseState(0);
        mockTransferValidator = new CreatorTokenTransferValidator(
            address(this), address(eoaRegistry), "", "", address(validatorConfiguration)
        );
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
        _mintToken(owner, 1);

        assertEq(1, core.balanceOf(owner, 0));

        vm.prank(owner);
        core.setApprovalForAll(address(transferTokenContract), true);

        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 0, 1);

        assertEq(1, core.balanceOf(permissionedActor, 0));
    }

    function test_transferRestrictedWithValidValidator() public {
        _mintToken(owner, 1);

        assertEq(1, core.balanceOf(owner, 0));

        // set transfer validator
        vm.prank(owner);
        CreatorTokenERC1155(address(core)).setTransferValidator(address(mockTransferValidator));

        // attempt to transfer token from owner to permissionedActor
        vm.prank(owner);
        core.setApprovalForAll(address(transferTokenContract), true);

        vm.expectRevert(0xef28f901);
        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 0, 1);

        assertEq(0, core.balanceOf(permissionedActor, 0));
    }

    function _mintToken(address to, uint256 quantity) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC1155(address(core)).setSaleConfig(saleRecipient);

        MintableERC1155.MintRequestERC1155 memory mintRequest = MintableERC1155.MintRequestERC1155({
            tokenId: 0,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            recipient: to,
            quantity: quantity,
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: bytes32("1"),
            metadataURI: "https://example.com/"
        });
        bytes memory sig = signMintRequest(mintRequest, ownerPrivateKey);

        MintableERC1155.MintParamsERC1155 memory params = MintableERC1155.MintParamsERC1155(mintRequest, sig, "");

        vm.prank(owner);
        core.mint{value: mintRequest.quantity * mintRequest.pricePerUnit}(
            mintRequest.recipient, mintRequest.tokenId, mintRequest.quantity, abi.encode(params)
        );
    }
}
