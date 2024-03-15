// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TestPlus} from "../utils/TestPlus.sol";
import {EmptyHookERC1155} from "../mocks/EmptyHook.sol";

import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {IERC1155Hook} from "src/interface/hook/IERC1155Hook.sol";
import {IHookInstaller} from "src/interface/hook/IHookInstaller.sol";

abstract contract ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data)
        public
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155Received.selector)));
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155BatchReceived.selector)));
    }
}

contract WrongReturnDataERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }
}

contract NonERC1155Recipient {}

contract ERC1155CoreTest is Test, TestPlus {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed approved, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    address public admin = address(0x123);

    CloneFactory public cloneFactory;

    address public hookProxyAddress;

    ERC1155Core public token;

    IERC1155Hook.MintRequest public mintRequest;
    IERC1155Hook.BurnRequest public burnRequest;

    mapping(address => mapping(uint256 => uint256)) public userMintAmounts;
    mapping(address => mapping(uint256 => uint256)) public userTransferOrBurnAmounts;
    mapping(uint256 => uint256) public supply;

    function setUp() public {
        cloneFactory = new CloneFactory();
        hookProxyAddress = cloneFactory.deployDeterministicERC1967(address(new EmptyHookERC1155()), "", bytes32("salt"));

        vm.startPrank(admin);

        ERC1155Core.OnInitializeParams memory onInitializeCall;
        ERC1155Core.InstallHookParams[] memory hooksToInstallOnInit;

        token = new ERC1155Core(
            "Token",
            "TKN",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            admin, // core contract owner
            onInitializeCall,
            hooksToInstallOnInit
        );
        token.installHook(IHookInstaller.InstallHookParams(IHook(hookProxyAddress), 0, bytes("")));

        vm.stopPrank();

        vm.label(address(token), "ERC1155Core");
        vm.label(admin, "Admin");
    }

    function testMintToEOA() public {
        mintRequest.minter = address(0xBEEF);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;

        token.mint(mintRequest);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.totalSupply(1337), 1);
    }

    function testMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        mintRequest.minter = address(to);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;

        token.mint(mintRequest);

        assertEq(token.balanceOf(address(to), 1337), 1);
        assertEq(token.totalSupply(1337), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
    }

    function testBurn() public {
        mintRequest.minter = address(0xBEEF);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);
        assertEq(token.totalSupply(1337), 100);

        burnRequest.owner = address(0xBEEF);
        burnRequest.tokenId = 1337;
        burnRequest.quantity = 70;

        vm.prank(address(0xBEEF));
        token.burn(burnRequest);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 30);
        assertEq(token.totalSupply(1337), 30);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        mintRequest.minter = address(from);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), 1337, 70, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 70);
        assertEq(token.balanceOf(from, 1337), 30);
        assertEq(token.totalSupply(1337), 100);
    }

    function testSafeTransferFromToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = address(0xABCD);
        mintRequest.minter = address(from);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(to), 1337, 70, "");

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), 1337);

        assertEq(token.balanceOf(address(to), 1337), 70);
        assertEq(token.balanceOf(from, 1337), 30);
        assertEq(token.totalSupply(1337), 100);
    }

    function testSafeTransferFromSelf() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), address(0xBEEF), 1337, 70, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 70);
        assertEq(token.balanceOf(address(0xCAFE), 1337), 30);
        assertEq(token.totalSupply(1337), 100);
    }

    function testSafeBatchTransferFromToEOA() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(0xBEEF), ids, transferAmounts, "");

        assertEq(token.balanceOf(from, 1337), 50);
        assertEq(token.balanceOf(address(0xBEEF), 1337), 50);

        assertEq(token.balanceOf(from, 1338), 100);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 100);

        assertEq(token.balanceOf(from, 1339), 150);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 150);

        assertEq(token.balanceOf(from, 1340), 200);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 200);

        assertEq(token.balanceOf(from, 1341), 250);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 250);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        address from = address(0xABCD);

        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(to), ids, transferAmounts, "");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), from);
        assertEq(to.batchIds(), ids);
        assertEq(to.batchAmounts(), transferAmounts);

        assertEq(token.balanceOf(from, 1337), 50);
        assertEq(token.balanceOf(address(to), 1337), 50);

        assertEq(token.balanceOf(from, 1338), 100);
        assertEq(token.balanceOf(address(to), 1338), 100);

        assertEq(token.balanceOf(from, 1339), 150);
        assertEq(token.balanceOf(address(to), 1339), 150);

        assertEq(token.balanceOf(from, 1340), 200);
        assertEq(token.balanceOf(address(to), 1340), 200);

        assertEq(token.balanceOf(from, 1341), 250);
        assertEq(token.balanceOf(address(to), 1341), 250);
    }

    function testBatchBalanceOf() public {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        mintRequest.minter = address(0xBEEF);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.minter = address(0xFACE);
        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.minter = address(0xDEAD);
        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.minter = address(0xFEED);
        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        uint256[] memory balances = token.balanceOfBatch(tos, ids);

        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
        assertEq(balances[3], 400);
        assertEq(balances[4], 500);
    }

    function test_revert_MintToZero() public {
        mintRequest.minter = address(0);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;

        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToZeroAddress.selector));
        token.mint(mintRequest);
    }

    function testFailMintToNonERC155Recipient() public {
        mintRequest.minter = address(new NonERC1155Recipient());
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;

        token.mint(mintRequest);
    }

    function testFailMintToRevertingERC155Recipient() public {
        mintRequest.minter = address(new RevertingERC1155Recipient());
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;
        token.mint(mintRequest);
    }

    function test_revert_MintToWrongReturnDataERC155Recipient() public {
        mintRequest.minter = address(new WrongReturnDataERC1155Recipient());
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 1;

        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToNonERC1155ReceiverImplementer.selector));
        token.mint(mintRequest);
    }

    function test_revert_BurnInsufficientBalance() public {
        mintRequest.minter = address(0xBEEF);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 70;

        token.mint(mintRequest);

        burnRequest.owner = address(0xBEEF);
        burnRequest.tokenId = 1337;
        burnRequest.quantity = 100;

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(ERC1155.InsufficientBalance.selector));
        token.burn(burnRequest);
    }

    function testFailSafeTransferFromInsufficientBalance() public {
        address from = address(0xABCD);
        mintRequest.minter = from;
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 70;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), 1337, 100, "");
    }

    function testFailSafeTransferFromSelfInsufficientBalance() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 70;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), address(0xBEEF), 1337, 100, "");
    }

    function test_revert_SafeTransferFromToZero() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToZeroAddress.selector));
        token.safeTransferFrom(address(0xCAFE), address(0), 1337, 70, "");
    }

    function testFailSafeTransferFromToNonERC155Recipient() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        address recipient = address(new NonERC1155Recipient());

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), recipient, 1337, 70, "");
    }

    function testFailSafeTransferFromToRevertingERC1155Recipient() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        address recipient = address(new RevertingERC1155Recipient());

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), recipient, 1337, 70, "");
    }

    function test_revert_SafeTransferFromToWrongReturnDataERC1155Recipient() public {
        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;

        token.mint(mintRequest);

        address recipient = address(new WrongReturnDataERC1155Recipient());

        vm.prank(address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToNonERC1155ReceiverImplementer.selector));
        token.safeTransferFrom(address(0xCAFE), recipient, 1337, 70, "");
    }

    function testFailSafeBatchTransferInsufficientBalance() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);

        mintAmounts[0] = 50;
        mintAmounts[1] = 100;
        mintAmounts[2] = 150;
        mintAmounts[3] = 200;
        mintAmounts[4] = 250;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 100;
        transferAmounts[1] = 200;
        transferAmounts[2] = 300;
        transferAmounts[3] = 400;
        transferAmounts[4] = 500;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 50;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 150;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 250;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(0xBEEF), ids, transferAmounts, "");
    }

    function test_revert_SafeBatchTransferFromToZero() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToZeroAddress.selector));
        token.safeBatchTransferFrom(from, address(0), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToNonERC1155Recipient() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(new NonERC1155Recipient()), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToRevertingERC1155Recipient() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(new RevertingERC1155Recipient()), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(new WrongReturnDataERC1155Recipient()), ids, transferAmounts, "");
    }

    function testFailSafeBatchTransferFromWithArrayLengthMismatch() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](4);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;

        mintRequest.minter = address(from);

        mintRequest.tokenId = 1337;
        mintRequest.quantity = 100;
        token.mint(mintRequest);

        mintRequest.tokenId = 1338;
        mintRequest.quantity = 200;
        token.mint(mintRequest);

        mintRequest.tokenId = 1339;
        mintRequest.quantity = 300;
        token.mint(mintRequest);

        mintRequest.tokenId = 1340;
        mintRequest.quantity = 400;
        token.mint(mintRequest);

        mintRequest.tokenId = 1341;
        mintRequest.quantity = 500;
        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(0xBEEF), ids, transferAmounts, "");
    }

    function test_revert_BalanceOfBatchWithArrayMismatch() public {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](4);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;

        vm.expectRevert(abi.encodeWithSelector(ERC1155.ArrayLengthsMismatch.selector));
        token.balanceOfBatch(tos, ids);
    }

    function testMintToEOA(address to, uint256 id, uint256 amount) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        mintRequest.minter = to;
        mintRequest.tokenId = id;
        mintRequest.quantity = amount;

        token.mint(mintRequest);

        assertEq(token.balanceOf(to, id), amount);
        assertEq(token.totalSupply(id), amount);
    }

    function testMintToERC1155Recipient(uint256 id, uint256 amount) public {
        ERC1155Recipient to = new ERC1155Recipient();

        mintRequest.minter = address(to);
        mintRequest.tokenId = id;
        mintRequest.quantity = amount;

        token.mint(mintRequest);

        assertEq(token.balanceOf(address(to), id), amount);
        assertEq(token.totalSupply(id), amount);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
    }

    function testBurn(address to, uint256 id, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0);

        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        burnAmount = _hem(burnAmount, 0, mintAmount);

        mintRequest.minter = to;
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        burnRequest.owner = to;
        burnRequest.tokenId = id;
        burnRequest.quantity = burnAmount;

        vm.prank(to);
        token.burn(burnRequest);

        assertEq(token.balanceOf(address(to), id), mintAmount - burnAmount);
        assertEq(token.totalSupply(id), mintAmount - burnAmount);
    }

    function testApproveAll(address to, bool approved) public {
        token.setApprovalForAll(to, approved);

        assertEq(token.isApprovedForAll(address(this), to), approved);
    }

    function testSafeTransferFromToEOA(uint256 id, uint256 mintAmount, uint256 transferAmount, address to) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        transferAmount = _hem(transferAmount, 0, mintAmount);

        address from = address(0xABCD);

        mintRequest.minter = from;
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, to, id, transferAmount, "");

        if (to == from) {
            assertEq(token.balanceOf(to, id), mintAmount);
            assertEq(token.totalSupply(id), mintAmount);
        } else {
            assertEq(token.balanceOf(to, id), transferAmount);
            assertEq(token.balanceOf(from, id), mintAmount - transferAmount);
            assertEq(token.totalSupply(id), mintAmount);
        }
    }

    function testSafeTransferFromToERC1155Recipient(uint256 id, uint256 mintAmount, uint256 transferAmount) public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = address(0xABCD);

        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = from;
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(to), id, transferAmount, "");

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), id);

        assertEq(token.balanceOf(address(to), id), transferAmount);
        assertEq(token.totalSupply(id), mintAmount);
    }

    function testSafeTransferFromSelf(uint256 id, uint256 mintAmount, uint256 transferAmount, address to) public {
        vm.assume(address(0xCAFE) != to);

        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), to, id, transferAmount, "");

        assertEq(token.balanceOf(to, id), transferAmount);
        assertEq(token.balanceOf(address(0xCAFE), id), mintAmount - transferAmount);
        assertEq(token.totalSupply(id), mintAmount);
    }

    function testSafeBatchTransferFromToEOA(
        address to,
        uint256[] memory ids,
        uint256[] memory mintAmounts,
        uint256[] memory transferAmounts
    ) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        address from = address(0xABCD);

        uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

        uint256[] memory normalizedIds = new uint256[](minLength);
        uint256[] memory normalizedMintAmounts = new uint256[](minLength);
        uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

        for (uint256 i = 0; i < minLength; i++) {
            uint256 id = ids[i];

            uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

            uint256 mintAmount = _hem(mintAmounts[i], 0, remainingMintAmountForId);
            uint256 transferAmount = _hem(transferAmounts[i], 0, mintAmount);

            supply[id] += mintAmount;

            normalizedIds[i] = id;
            normalizedMintAmounts[i] = mintAmount;
            normalizedTransferAmounts[i] = transferAmount;

            userMintAmounts[from][id] += mintAmount;
            userTransferOrBurnAmounts[from][id] += transferAmount;

            mintRequest.minter = from;
            mintRequest.tokenId = id;
            mintRequest.quantity = mintAmount;

            token.mint(mintRequest);
        }

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, to, normalizedIds, normalizedTransferAmounts, "");

        for (uint256 i = 0; i < normalizedIds.length; i++) {
            uint256 id = normalizedIds[i];

            assertEq(token.balanceOf(address(to), id), userTransferOrBurnAmounts[from][id]);
            assertEq(token.balanceOf(from, id), userMintAmounts[from][id] - userTransferOrBurnAmounts[from][id]);
            assertEq(token.totalSupply(id), supply[id]);
        }
    }

    function testSafeBatchTransferFromToERC1155Recipient(
        uint256[] memory ids,
        uint256[] memory mintAmounts,
        uint256[] memory transferAmounts
    ) public {
        address from = address(0xABCD);

        ERC1155Recipient to = new ERC1155Recipient();

        uint256 minLength = min3(ids.length, mintAmounts.length, transferAmounts.length);

        uint256[] memory normalizedIds = new uint256[](minLength);
        uint256[] memory normalizedMintAmounts = new uint256[](minLength);
        uint256[] memory normalizedTransferAmounts = new uint256[](minLength);

        for (uint256 i = 0; i < minLength; i++) {
            uint256 id = ids[i];

            uint256 remainingMintAmountForId = type(uint256).max - userMintAmounts[from][id];

            uint256 mintAmount = _hem(mintAmounts[i], 0, remainingMintAmountForId);
            uint256 transferAmount = _hem(transferAmounts[i], 0, mintAmount);

            supply[id] += mintAmount;

            normalizedIds[i] = id;
            normalizedMintAmounts[i] = mintAmount;
            normalizedTransferAmounts[i] = transferAmount;

            userMintAmounts[from][id] += mintAmount;
            userTransferOrBurnAmounts[from][id] += transferAmount;

            mintRequest.minter = from;
            mintRequest.tokenId = id;
            mintRequest.quantity = mintAmount;

            token.mint(mintRequest);
        }

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(from, address(to), normalizedIds, normalizedTransferAmounts, "");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), from);
        assertEq(to.batchIds(), normalizedIds);
        assertEq(to.batchAmounts(), normalizedTransferAmounts);

        for (uint256 i = 0; i < normalizedIds.length; i++) {
            uint256 id = normalizedIds[i];
            uint256 transferAmount = userTransferOrBurnAmounts[from][id];

            assertEq(token.balanceOf(address(to), id), transferAmount);
            assertEq(token.balanceOf(from, id), userMintAmounts[from][id] - transferAmount);
            assertEq(token.totalSupply(id), supply[id]);
        }
    }

    function test_revert_MintToZero(uint256 id, uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToZeroAddress.selector));

        mintRequest.minter = address(0);
        mintRequest.tokenId = id;
        mintRequest.quantity = amount;

        token.mint(mintRequest);
    }

    function testFailMintToNonERC155Recipient(uint256 id, uint256 mintAmount) public {
        mintRequest.minter = address(new NonERC1155Recipient());
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);
    }

    function testFailMintToRevertingERC155Recipient(uint256 id, uint256 mintAmount) public {
        mintRequest.minter = address(new RevertingERC1155Recipient());
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);
    }

    function testFailMintToWrongReturnDataERC155Recipient(uint256 id, uint256 mintAmount) public {
        mintRequest.minter = address(new RevertingERC1155Recipient());
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);
    }

    function testFailBurnInsufficientBalance(address to, uint256 id, uint256 mintAmount, uint256 burnAmount) public {
        burnAmount = _hem(burnAmount, mintAmount + 1, type(uint256).max);

        mintRequest.minter = to;
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        burnRequest.owner = to;
        burnRequest.tokenId = id;
        burnRequest.quantity = burnAmount;

        token.mint(mintRequest);
        token.burn(burnRequest);
    }

    function testFailSafeTransferFromInsufficientBalance(
        address to,
        uint256 id,
        uint256 mintAmount,
        uint256 transferAmount
    ) public {
        address from = address(0xABCD);

        transferAmount = _hem(transferAmount, mintAmount + 1, type(uint256).max);

        mintRequest.minter = from;
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, to, id, transferAmount, "");
    }

    function testFailSafeTransferFromSelfInsufficientBalance(
        address to,
        uint256 id,
        uint256 mintAmount,
        uint256 transferAmount
    ) public {
        transferAmount = _hem(transferAmount, mintAmount + 1, type(uint256).max);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), to, id, transferAmount, "");
    }

    function test_revert_SafeTransferFromToZero(uint256 id, uint256 mintAmount, uint256 transferAmount) public {
        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        vm.expectRevert(abi.encodeWithSelector(ERC1155.TransferToZeroAddress.selector));
        token.safeTransferFrom(address(0xCAFE), address(0), id, transferAmount, "");
    }

    function testFailSafeTransferFromToNonERC155Recipient(uint256 id, uint256 mintAmount, uint256 transferAmount)
        public
    {
        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), address(new NonERC1155Recipient()), id, transferAmount, "");
    }

    function testFailSafeTransferFromToRevertingERC1155Recipient(uint256 id, uint256 mintAmount, uint256 transferAmount)
        public
    {
        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), address(new RevertingERC1155Recipient()), id, transferAmount, "");
    }

    function testFailSafeTransferFromToWrongReturnDataERC1155Recipient(
        uint256 id,
        uint256 mintAmount,
        uint256 transferAmount
    ) public {
        transferAmount = _hem(transferAmount, 0, mintAmount);

        mintRequest.minter = address(0xCAFE);
        mintRequest.tokenId = id;
        mintRequest.quantity = mintAmount;

        token.mint(mintRequest);

        vm.prank(address(0xCAFE));
        token.safeTransferFrom(address(0xCAFE), address(new WrongReturnDataERC1155Recipient()), id, transferAmount, "");
    }
}
