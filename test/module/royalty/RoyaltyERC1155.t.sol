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

struct CollectionSecurityPolicyV3 {
    bool disableAuthorizationMode;
    bool authorizersCannotSetWildcardOperators;
    uint8 transferSecurityLevel;
    uint120 listId;
    bool enableAccountFreezingMode;
    uint16 tokenType;
}

interface CreatorTokenTransferValidator is ITransferValidator {

    function setTransferSecurityLevelOfCollection(
        address collection,
        uint8 transferSecurityLevel,
        bool isTransferRestricted,
        bool isTransferWithRestrictedRecipient,
        bool isTransferWithRestrictedToken
    ) external;
    function getCollectionSecurityPolicy(address collection)
        external
        view
        returns (CollectionSecurityPolicyV3 memory);

}

contract RoyaltyERC1155Test is Test {

    ERC1155Core public core;

    RoyaltyExt public moduleImplementation;

    MintableERC1155 public mintableModuleImplementation;
    TransferToken public transferTokenContract;
    CreatorTokenTransferValidator public mockTransferValidator;
    uint8 TRANSFER_SECURITY_LEVEL_SEVEN = 7;

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

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC1155Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new RoyaltyExt();
        mintableModuleImplementation = new MintableERC1155();

        transferTokenContract = new TransferToken();

        // install module
        bytes memory moduleInitializeData = moduleImplementation.encodeBytesOnInstall(owner, 100, address(0));
        bytes memory mintableModuleInitializeData = mintableModuleImplementation.encodeBytesOnInstall(owner);

        vm.startPrank(owner);
        core.installModule(address(moduleImplementation), moduleInitializeData);
        core.installModule(address(mintableModuleImplementation), mintableModuleInitializeData);
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
        mockTransferValidator = CreatorTokenTransferValidator(0x721C0078c2328597Ca70F5451ffF5A7B38D4E947);
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
        vm.expectRevert(RoyaltyERC1155.RoyaltyInvalidTransferValidatorContract.selector);
        RoyaltyERC1155(address(core)).setTransferValidator(address(11_111));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `validateTransfer`
    //////////////////////////////////////////////////////////////*/

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
        values[0] = 1;
        values[1] = 1;

        vm.expectRevert(0xef28f901);
        transferTokenContract.batchTransferToken(payable(address(core)), owner, permissionedActor, tokenIds, values);

        assertEq(0, core.balanceOf(permissionedActor, 0));
        assertEq(0, core.balanceOf(permissionedActor, 1));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTransferPolicy`
    //////////////////////////////////////////////////////////////*/

    function test_setTransferSecurityLevel() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }

        // set transfer validator
        vm.prank(owner);
        RoyaltyERC1155(address(core)).setTransferValidator(address(mockTransferValidator));

        vm.prank(owner);
        core.grantRoles(permissionedActor, Role._MANAGER_ROLE);

        vm.prank(permissionedActor);
        mockTransferValidator.setTransferSecurityLevelOfCollection(
            address(core), TRANSFER_SECURITY_LEVEL_SEVEN, true, false, false
        );

        assertEq(
            mockTransferValidator.getCollectionSecurityPolicy(address(core)).transferSecurityLevel,
            TRANSFER_SECURITY_LEVEL_SEVEN
        );
    }

    function test_revert_setTransferSecurityLevel() public {
        if (evmVersionHash != keccak256(abi.encode('evm_version = "cancun"'))) {
            //skip test if evm version is not cancun
            return;
        }
        vm.prank(owner);
        core.grantRoles(permissionedActor, Role._MANAGER_ROLE);

        // revert due to msg.sender not being the transfer validator
        vm.expectRevert();
        vm.prank(permissionedActor);
        mockTransferValidator.setTransferSecurityLevelOfCollection(
            address(core), TRANSFER_SECURITY_LEVEL_SEVEN, true, false, false
        );

        // set transfer validator
        vm.prank(owner);
        RoyaltyERC1155(address(core)).setTransferValidator(address(mockTransferValidator));

        // revert due to incorrect permissions
        vm.prank(unpermissionedActor);
        vm.expectRevert();
        mockTransferValidator.setTransferSecurityLevelOfCollection(
            address(core), TRANSFER_SECURITY_LEVEL_SEVEN, true, false, false
        );
    }

    /*///////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
