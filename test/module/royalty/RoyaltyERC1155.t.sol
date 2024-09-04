// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import "./RoyaltyUtils.sol";
import {Test} from "forge-std/Test.sol";

// Target contract

import {Module} from "src/Module.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";
import {Role} from "src/Role.sol";
import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {MintableERC1155} from "src/module/token/minting/MintableERC1155.sol";
import {RoyaltyERC1155} from "src/module/token/royalty/RoyaltyERC1155.sol";
import {TokenIdERC1155} from "src/module/token/tokenId/tokenIdERC1155.sol";

contract RoyaltyExt is RoyaltyERC1155 {}

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

contract RoyaltyERC1155Test is Test {

    ERC1155Core public core;

    RoyaltyExt public moduleImplementation;

    MintableERC1155 public mintableModuleImplementation;
    TransferToken public transferTokenContract;
    TokenIdERC1155 public tokenIdModule;
    ITransferValidator public mockTransferValidator;

    uint256 ownerPrivateKey = 1;
    address public owner;
    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;
    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient;
    uint256 quantity = 100;
    uint256 tokenId = 0;
    string baseURI = "";

    bytes32 internal typehashMintSignatureParams;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    MintableERC1155.MintSignatureParamsERC1155 public mintRequest;

    bytes32 internal evmVersionHash;

    // Util fn
    function signMintSignatureParams(MintableERC1155.MintSignatureParamsERC1155 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashMintSignatureParams,
            tokenRecipient,
            tokenId,
            quantity,
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
        tokenRecipient = vm.addr(ownerPrivateKey);
        permissionedActor = vm.addr(permissionedActorPrivateKey);
        unpermissionedActor = vm.addr(unpermissionedActorPrivateKey);

        evmVersionHash = _checkEVMVersion();

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC1155Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new RoyaltyExt();
        mintableModuleImplementation = new MintableERC1155();
        tokenIdModule = new TokenIdERC1155();

        transferTokenContract = new TransferToken();

        // install module
        bytes memory moduleInitializeData = moduleImplementation.encodeBytesOnInstall(owner, 100, address(0));
        bytes memory mintableModuleInitializeData = mintableModuleImplementation.encodeBytesOnInstall(owner);

        vm.startPrank(owner);
        core.installModule(address(moduleImplementation), moduleInitializeData);
        core.installModule(address(mintableModuleImplementation), mintableModuleInitializeData);
        core.installModule(address(tokenIdModule), "");
        vm.stopPrank();

        typehashMintSignatureParams =
            keccak256("MintRequestERC1155(address to,uint256 tokenId,uint256 amount,string baseURI,bytes data)");
        nameHash = keccak256(bytes("ERC1155Core"));
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
                        Unit tests: `setDefaultRoyaltyInfo`
    //////////////////////////////////////////////////////////////*/

    function test_state_setDefaultRoyaltyInfo() public {
        address royaltyRecipient = address(0x123);
        uint16 royaltyBps = 100;

        vm.prank(owner);
        RoyaltyExt(address(core)).setDefaultRoyaltyInfo(royaltyRecipient, royaltyBps);

        address receiver;
        uint256 royaltyAmount;
        uint16 bps;

        // read state from module
        (receiver, bps) = RoyaltyExt(address(core)).getDefaultRoyaltyInfo();
        assertEq(receiver, royaltyRecipient);
        assertEq(bps, royaltyBps);
        (receiver, bps) = RoyaltyExt(address(core)).getRoyaltyInfoForToken(1);
        assertEq(receiver, address(0));
        assertEq(bps, 0);

        // read state from core
        uint256 salePrice = 1000;
        uint256 tokenId = 1;
        (receiver, royaltyAmount) = RoyaltyExt(address(core)).royaltyInfo(tokenId, salePrice);
        assertEq(receiver, royaltyRecipient);
        assertEq(royaltyAmount, (salePrice * royaltyBps) / 10_000);
    }

    function test_revert_setDefaultRoyaltyInfo() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        RoyaltyExt(address(core)).setDefaultRoyaltyInfo(address(0x123), 100);
    }

    function test_state_setRoyaltyInfoForToken() public {
        address defaultRoyaltyRecipient = address(0x123);
        uint16 defaultRoyaltyBps = 100;

        address customRoyaltyRecipient = address(0x345);
        uint16 customRoyaltyBps = 200;

        vm.startPrank(owner);
        RoyaltyExt(address(core)).setDefaultRoyaltyInfo(defaultRoyaltyRecipient, defaultRoyaltyBps);
        RoyaltyExt(address(core)).setRoyaltyInfoForToken(10, customRoyaltyRecipient, customRoyaltyBps);
        vm.stopPrank();

        address receiver;
        uint256 royaltyAmount;
        uint16 bps;

        // read state from module
        (receiver, bps) = RoyaltyExt(address(core)).getDefaultRoyaltyInfo();
        assertEq(receiver, defaultRoyaltyRecipient);
        assertEq(bps, defaultRoyaltyBps);
        (receiver, bps) = RoyaltyExt(address(core)).getRoyaltyInfoForToken(1);
        assertEq(receiver, address(0));
        assertEq(bps, 0);
        (receiver, bps) = RoyaltyExt(address(core)).getRoyaltyInfoForToken(10);
        assertEq(receiver, customRoyaltyRecipient);
        assertEq(bps, customRoyaltyBps);

        // read state from core
        uint256 salePrice = 1000;
        uint256 tokenId = 1;

        (receiver, royaltyAmount) = RoyaltyExt(address(core)).royaltyInfo(tokenId, salePrice); // default royalty
        assertEq(receiver, defaultRoyaltyRecipient);
        assertEq(royaltyAmount, (salePrice * defaultRoyaltyBps) / 10_000);

        tokenId = 10;
        (receiver, royaltyAmount) = RoyaltyExt(address(core)).royaltyInfo(tokenId, salePrice); // custom royalty
        assertEq(receiver, customRoyaltyRecipient);
        assertEq(royaltyAmount, (salePrice * customRoyaltyBps) / 10_000);
    }

    function test_revert_setRoyaltyInfoForToken() public {
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        RoyaltyExt(address(core)).setRoyaltyInfoForToken(10, address(0x123), 100);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTransferValidator`
    //////////////////////////////////////////////////////////////*/

    function test_state_setTransferValidator() public {
        assertEq(RoyaltyERC1155(address(core)).getTransferValidator(), address(0));

        // set transfer validator
        vm.prank(owner);
        RoyaltyERC1155(address(core)).setTransferValidator(address(mockTransferValidator));
        assertEq(RoyaltyERC1155(address(core)).getTransferValidator(), address(mockTransferValidator));

        // set transfer validator back to zero address
        vm.prank(owner);
        RoyaltyERC1155(address(core)).setTransferValidator(address(0));
        assertEq(RoyaltyERC1155(address(core)).getTransferValidator(), address(0));
    }

    function test_revert_setTransferValidator_accessControl() public {
        // attemp to set the transfer validator from an unpermissioned actor
        vm.prank(unpermissionedActor);
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        RoyaltyERC1155(address(core)).setTransferValidator(address(mockTransferValidator));
    }

    function test_revert_setTransferValidator_invalidContract() public {
        // attempt to set the transfer validator to an invalid contract
        vm.prank(owner);
        vm.expectRevert(RoyaltyERC1155.InvalidTransferValidatorContract.selector);
        RoyaltyERC1155(address(core)).setTransferValidator(address(11_111));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `validateTransfer`
    //////////////////////////////////////////////////////////////*/

    function test_allowsTransferWithTransferValidatorAddressZero() public {
        _mintToken(bytes32("1"));
        _mintToken(bytes32("2"));

        assertEq(200, core.balanceOf(owner, 0));
        assertEq(0, core.balanceOf(owner, 1));

        vm.prank(owner);
        core.setApprovalForAll(address(transferTokenContract), true);

        transferTokenContract.transferToken(payable(address(core)), owner, permissionedActor, 0, 10);

        assertEq(10, core.balanceOf(permissionedActor, 0));

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256[] memory values = new uint256[](2);
        values[0] = 50;
        values[1] = 0;

        transferTokenContract.batchTransferToken(payable(address(core)), owner, permissionedActor, tokenIds, values);

        assertEq(60, core.balanceOf(permissionedActor, 0));
        assertEq(0, core.balanceOf(permissionedActor, 1));
    }

    function test_transferRestrictedWithValidValidator() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }

        _mintToken(bytes32("1"));
        _mintToken(bytes32("2"));

        assertEq(200, core.balanceOf(owner, 0));
        assertEq(0, core.balanceOf(owner, 1));

        // set transfer validator
        vm.prank(owner);
        RoyaltyERC1155(address(core)).setTransferValidator(address(mockTransferValidator));

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
        values[0] = 50;
        values[1] = 0;

        vm.expectRevert(0xef28f901);
        transferTokenContract.batchTransferToken(payable(address(core)), owner, permissionedActor, tokenIds, values);

        assertEq(0, core.balanceOf(permissionedActor, 0));
        assertEq(0, core.balanceOf(permissionedActor, 1));
    }

    /*///////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintToken(bytes32 uid) internal {
        address saleRecipient = address(0x987);

        vm.prank(owner);
        MintableERC1155(address(core)).setSaleConfig(saleRecipient);

        MintableERC1155.MintSignatureParamsERC1155 memory mintRequest = MintableERC1155.MintSignatureParamsERC1155({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            pricePerUnit: 0,
            uid: uid
        });
        bytes memory sig = signMintSignatureParams(mintRequest, ownerPrivateKey);

        vm.prank(owner);
        core.mintWithSignature{value: quantity * mintRequest.pricePerUnit}(
            tokenRecipient, tokenId, quantity, baseURI, abi.encode(mintRequest), sig
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
