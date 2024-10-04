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

import {MockMintFeeManager} from "../../mock/MockMintFeeManager.sol";
import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {ClaimableERC721} from "src/module/token/minting/ClaimableERC721.sol";

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

contract ClaimableERC721Test is Test {

    ERC721Core public core;

    ClaimableERC721 public claimableModule;
    BatchMetadataERC721 public batchMetadataModule;
    MockMintFeeManager public mintFeeManager;

    uint256 ownerPrivateKey = 1;
    address public owner;

    uint256 public permissionedActorPrivateKey = 2;
    address public permissionedActor;

    uint256 unpermissionedActorPrivateKey = 3;
    address public unpermissionedActor;

    address tokenRecipient = address(0x123);
    uint256 amount = 100;
    string baseURI = "ipfs://base/";
    address feeRecipient;

    // Signature vars
    bytes32 internal typehashClaimSignatureParams;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    ClaimableERC721.ClaimSignatureParamsERC721 public claimRequest;
    ClaimableERC721.ClaimCondition public claimCondition;

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Util fn
    function signMintRequest(ClaimableERC721.ClaimSignatureParamsERC721 memory _req, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedRequest = abi.encode(
            typehashClaimSignatureParams,
            tokenRecipient,
            amount,
            keccak256(bytes(baseURI)),
            keccak256(
                abi.encode(
                    _req.startTimestamp,
                    _req.endTimestamp,
                    _req.currency,
                    _req.maxMintPerWallet,
                    _req.pricePerUnit,
                    _req.uid
                )
            )
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
        mintFeeManager = new MockMintFeeManager();
        claimableModule = new ClaimableERC721(address(mintFeeManager));
        batchMetadataModule = new BatchMetadataERC721();

        // install module
        bytes memory encodedInstallParams = abi.encode(owner);
        vm.prank(owner);
        core.installModule(address(claimableModule), encodedInstallParams);

        bytes memory encodedBatchMetadataInstallParams = "";
        vm.prank(owner);
        core.installModule(address(batchMetadataModule), encodedBatchMetadataInstallParams);

        // setup platform fee receipient
        feeRecipient = mintFeeManager.getPlatformFeeReceipient();

        // Setup signature vars
        typehashClaimSignatureParams =
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
                        Tests: get / set Claim Condition
    //////////////////////////////////////////////////////////////*/

    function test_setClaimCondition_state() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        ClaimableERC721.ClaimCondition memory storedCondition = ClaimableERC721(address(core)).getClaimCondition();

        assertEq(storedCondition.availableSupply, condition.availableSupply);
        assertEq(storedCondition.pricePerUnit, condition.pricePerUnit);
        assertEq(storedCondition.currency, condition.currency);
        assertEq(storedCondition.startTimestamp, condition.startTimestamp);
        assertEq(storedCondition.endTimestamp, condition.endTimestamp);
        assertEq(storedCondition.auxData, condition.auxData);
    }

    function test_setClaimCondition_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        ClaimableERC721(address(core)).setClaimCondition(
            ClaimableERC721.ClaimCondition({
                availableSupply: 100 ether,
                pricePerUnit: 0.1 ether,
                currency: NATIVE_TOKEN_ADDRESS,
                maxMintPerWallet: type(uint256).max,
                startTimestamp: uint48(block.timestamp),
                endTimestamp: uint48(block.timestamp + 100),
                auxData: "",
                allowlistMerkleRoot: bytes32(0)
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: get / set SaleConfig
    //////////////////////////////////////////////////////////////*/

    function test_saleConfig_state() public {
        address saleRecipient = address(0x123);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        address recipient = ClaimableERC721(address(core)).getSaleConfig();

        assertEq(recipient, saleRecipient);
    }

    function test_setSaleConfig_revert_unauthorizedCaller() public {
        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(0x82b42900)); // Unauthorized()
        ClaimableERC721(address(core)).setSaleConfig(address(0x123));
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: beforeMintERC721
    //////////////////////////////////////////////////////////////*/

    function test_mint_state() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        address saleRecipient = address(0x987);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        uint256 balBefore = tokenRecipient.balance;
        assertEq(balBefore, 100 ether);
        assertEq(saleRecipient.balance, 0);

        vm.prank(tokenRecipient);
        core.mintWithSignature{value: (amount * claimRequest.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );

        // Check minted balance
        assertEq(core.balanceOf(tokenRecipient), amount);

        uint256 salePrice = (amount * claimRequest.pricePerUnit);
        (uint256 primarySaleAmount, uint256 platformFeeAmount) =
            mintFeeManager.getPrimarySaleAndPlatformFeeAmount(salePrice);
        assertEq(tokenRecipient.balance, balBefore - salePrice, "tokenRecipient balance");
        assertEq(saleRecipient.balance, primarySaleAmount, "saleRecipient balance");
        assertEq(feeRecipient.balance, platformFeeAmount, "feeRecipient balance");
    }

    function test_mint_state_overridePrice() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.1 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        address saleRecipient = address(0x987);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.2 ether, // different price from condition
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        uint256 balBefore = tokenRecipient.balance;
        assertEq(balBefore, 100 ether);
        assertEq(saleRecipient.balance, 0);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: (amount * condition.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );

        vm.prank(tokenRecipient);
        core.mintWithSignature{value: (amount * claimRequest.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );

        // Check minted balance
        assertEq(core.balanceOf(address(0x123)), 100);

        uint256 salePrice = (amount * claimRequest.pricePerUnit);
        (uint256 primarySaleAmount, uint256 platformFeeAmount) =
            mintFeeManager.getPrimarySaleAndPlatformFeeAmount(salePrice);
        assertEq(tokenRecipient.balance, balBefore - salePrice, "tokenRecipient balance");
        assertEq(saleRecipient.balance, primarySaleAmount, "saleRecipient balance");
        assertEq(feeRecipient.balance, platformFeeAmount, "feeRecipient balance");
    }

    function test_mint_state_overrideCurrency() public {
        MockCurrency currency = new MockCurrency();

        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.1 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        address saleRecipient = address(0x987);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: address(currency), // different currency from condition
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        currency.mintTo(tokenRecipient, 100 ether);

        uint256 balBefore = currency.balanceOf(tokenRecipient);
        assertEq(balBefore, 100 ether);
        assertEq(currency.balanceOf(saleRecipient), 0);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: (amount * claimRequest.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );

        uint256 salePrice = (amount * condition.pricePerUnit);

        vm.prank(tokenRecipient);
        currency.approve(address(core), salePrice);

        vm.prank(tokenRecipient);
        core.mintWithSignature(tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig);

        // Check minted balance
        assertEq(core.balanceOf(address(0x123)), 100);

        (uint256 primarySaleAmount, uint256 platformFeeAmount) =
            mintFeeManager.getPrimarySaleAndPlatformFeeAmount(salePrice);
        assertEq(currency.balanceOf(tokenRecipient), balBefore - salePrice, "tokenRecipient balance");
        assertEq(currency.balanceOf(saleRecipient), primarySaleAmount, "saleRecipient balance");
        assertEq(currency.balanceOf(feeRecipient), platformFeeAmount, "feeRecipient balance");
    }

    function test_mint_revert_unableToDecodeArgs() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: address(0),
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert();
        core.mintWithSignature{value: (amount * condition.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(bytes("random mixer")), sig
        );
    }

    function test_mint_revert_requestBeforeValidityStart() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp + 100), // tx before validity start
            endTimestamp: uint48(block.timestamp + 200),
            currency: address(0),
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableRequestOutOfTimeWindow.selector));
        core.mintWithSignature{value: (amount * condition.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );
    }

    function test_mint_revert_requestAfterValidityEnd() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200), // tx at / after validity end
            currency: address(0),
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.warp(claimRequest.endTimestamp);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableRequestOutOfTimeWindow.selector));
        core.mintWithSignature{value: (amount * condition.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );
    }

    function test_mint_revert_requestUidReused() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200), // tx at / after validity end
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        core.mintWithSignature{value: (amount * claimRequest.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );
        assertEq(core.balanceOf(tokenRecipient), amount);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequestTwo = claimRequest;
        claimRequestTwo.pricePerUnit = 0;

        bytes memory sigTwo = signMintRequest(claimRequestTwo, permissionedActorPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableRequestUidReused.selector));
        core.mintWithSignature(tokenRecipient, amount, baseURI, abi.encode(claimRequestTwo), sigTwo);
    }

    function test_mint_revert_requestUnauthorizedSigner() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: address(0),
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, ownerPrivateKey); // is owner but not MINTER_ROLE holder

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableSignatureMintUnauthorized.selector));
        core.mintWithSignature{value: (amount * condition.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );
    }

    function test_mint_revert_noPriceButNativeTokensSent() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: 1 ether}(tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig);
    }

    function test_mint_revert_incorrectNativeTokenSent() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectNativeTokenSent.selector));
        core.mintWithSignature{value: 5 ether}(tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig);
    }

    function test_mint_revert_insufficientERC721CurrencyBalance() public {
        MockCurrency currency = new MockCurrency();

        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: address(0),
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        assertEq(currency.balanceOf(tokenRecipient), 0);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 200),
            currency: address(currency),
            maxMintPerWallet: type(uint256).max,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(0x7939f424)); // TransferFromFailed()
        core.mintWithSignature(tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig);
    }

    function test_mint_revert_unexpectedPriceOrCurrency() public {
        MockCurrency currency = new MockCurrency();

        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        address saleRecipient = address(0x987);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimParamsERC721 memory params =
            ClaimableERC721.ClaimParamsERC721(address(currency), condition.pricePerUnit, new bytes32[](0)); // unexpected currrency

        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectPriceOrCurrency.selector));
        core.mint(tokenRecipient, amount, baseURI, abi.encode(params));

        params.currency = NATIVE_TOKEN_ADDRESS;
        params.pricePerUnit = 0.1 ether; // unexpected price

        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableIncorrectPriceOrCurrency.selector));
        core.mint(tokenRecipient, amount, baseURI, abi.encode(params));
    }

    function test_mint_revert_maxMintPerWalletExceeded() public {
        ClaimableERC721.ClaimCondition memory condition = ClaimableERC721.ClaimCondition({
            availableSupply: 1000 ether,
            pricePerUnit: 0.2 ether,
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: type(uint256).max,
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            auxData: "",
            allowlistMerkleRoot: bytes32(0)
        });

        vm.prank(owner);
        ClaimableERC721(address(core)).setClaimCondition(condition);

        address saleRecipient = address(0x987);

        vm.prank(owner);
        ClaimableERC721(address(core)).setSaleConfig(saleRecipient);

        vm.deal(tokenRecipient, 100 ether);

        ClaimableERC721.ClaimSignatureParamsERC721 memory claimRequest = ClaimableERC721.ClaimSignatureParamsERC721({
            startTimestamp: uint48(block.timestamp),
            endTimestamp: uint48(block.timestamp + 100),
            currency: NATIVE_TOKEN_ADDRESS,
            maxMintPerWallet: 10,
            pricePerUnit: 0.1 ether,
            uid: bytes32("1")
        });
        bytes memory sig = signMintRequest(claimRequest, permissionedActorPrivateKey);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSelector(ClaimableERC721.ClaimableMaxMintPerWalletExceeded.selector));
        core.mintWithSignature{value: (amount * claimRequest.pricePerUnit)}(
            tokenRecipient, amount, baseURI, abi.encode(claimRequest), sig
        );
    }

}
