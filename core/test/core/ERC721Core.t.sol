// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TestPlus} from "../utils/TestPlus.sol";
import {MockExtensionERC721} from "../mocks/MockExtension.sol";

import {EIP1967Proxy} from "test/utils/EIP1967Proxy.sol";

import {IERC721A, ERC721A, ERC721AQueryable} from "@erc721a/extensions/ERC721AQueryable.sol";

import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {CoreContract, ICoreContract} from "src/core/CoreContract.sol";

abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(address _operator, address _from, uint256 _id, bytes calldata _data)
        public
        virtual
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721CoreTest is Test, TestPlus {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed approved, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    address public admin = address(0x123);

    address public hookProxyAddress;

    ERC721Core public token;

    function setUp() public {
        bytes memory hookInitData = abi.encodeWithSelector(
            MockExtensionERC721.initialize.selector,
            address(0x123) // upgradeAdmin
        );
        hookProxyAddress = address(new EIP1967Proxy(address(new MockExtensionERC721()), hookInitData));

        vm.startPrank(admin);

        address[] memory extensionsToInstall = new address[](1);
        extensionsToInstall[0] = hookProxyAddress;

        token = new ERC721Core(
            "Token",
            "TKN",
            "ipfs://QmPVMvePSWfYXTa8haCbFavYx4GM4kBPzvdgBw7PTGUByp/0",
            admin, // core contract owner,
            extensionsToInstall,
            address(0),
            bytes("")
        );

        vm.stopPrank();

        vm.label(address(token), "ERC721Core");
        vm.label(admin, "Admin");
    }

    function testMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
    }

    function testMint() public {
        uint256 quantity = 10;

        address minter = address(0xBEEF);

        token.mint(minter, quantity, "");

        assertEq(token.balanceOf(address(0xBEEF)), quantity);

        for (uint256 i = 0; i < quantity; i++) {
            assertEq(token.ownerOf(i), address(0xBEEF));
        }
    }

    function testBurn() public {
        uint256 quantity = 10;
        uint256 idToBurn = 5;

        address minter = address(0xBEEF);

        token.mint(minter, quantity, "");

        address burner = address(0xBEEF);
        uint256 burnTokenId = idToBurn;

        vm.prank(address(0xBEEF));
        token.burn(burnTokenId, "");

        assertEq(token.balanceOf(address(0xBEEF)), quantity - 1);

        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.ownerOf(idToBurn);
    }

    function testApprove() public {
        uint256 quantity = 10;
        uint256 idToApprove = 5;

        address minter = address(this);

        token.mint(minter, quantity, "");

        token.approve(address(0xBEEF), idToApprove);

        assertEq(token.getApproved(idToApprove), address(0xBEEF));
    }

    function testApproveBurn() public {
        uint256 quantity = 10;
        uint256 idToBurn = 5;

        address minter = address(this);

        token.mint(minter, quantity, "");

        token.approve(address(0xBEEF), idToBurn);

        address burner = address(this);
        uint256 burnTokenId = idToBurn;

        token.burn(burnTokenId, "");

        assertEq(token.balanceOf(address(this)), quantity - 1);

        vm.expectRevert(abi.encodeWithSelector(IERC721A.ApprovalQueryForNonexistentToken.selector));
        token.getApproved(idToBurn);

        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.ownerOf(idToBurn);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testTransferFrom() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;

        address from = address(0xABCD);

        address minter = from;

        token.mint(minter, quantity, "");

        vm.prank(from);
        token.approve(address(this), tokenId);

        token.transferFrom(from, address(0xBEEF), tokenId);

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), quantity);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;

        address minter = address(this);

        token.mint(minter, quantity, "");

        token.transferFrom(address(this), address(0xBEEF), tokenId);

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), quantity);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;
        address from = address(0xABCD);

        address minter = address(from);

        token.mint(minter, quantity, "");

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, address(0xBEEF), tokenId);

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), quantity);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;
        address from = address(0xABCD);

        address minter = address(from);

        token.mint(minter, quantity, "");

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), tokenId);

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), quantity);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        address minter = address(from);

        token.mint(minter, quantity, "");

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), tokenId);

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(recipient));
        assertEq(token.balanceOf(address(recipient)), quantity);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), tokenId);
        assertEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        uint256 quantity = 1;
        uint256 tokenId = 0;
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        address minter = address(from);

        token.mint(minter, quantity, "");

        vm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), tokenId, "testing 123");

        assertEq(token.getApproved(tokenId), address(0));
        assertEq(token.ownerOf(tokenId), address(recipient));
        assertEq(token.balanceOf(address(recipient)), quantity);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), tokenId);
        assertEq(recipient.data(), "testing 123");
    }

    function test_revert_MintToZero() public {
        address minter = address(0);
        uint256 quantity = 1;

        vm.expectRevert(abi.encodeWithSelector(IERC721A.MintToZeroAddress.selector));
        token.mint(minter, quantity, "");
    }

    function test_revert_BurnUnMinted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.burn(0, "");
    }

    function test_revert_DoubleBurn() public {
        address minter = address(this);
        uint256 quantity = 5;

        token.mint(minter, quantity, "");

        address burner = address(this);
        uint256 burnTokenId = 1;

        token.burn(burnTokenId, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.burn(burnTokenId, "");
    }

    function test_revert_ApproveUnMinted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.approve(address(0xBEEF), 1337);
    }

    function test_revert_ApproveUnAuthorized() public {
        address minter = address(0xCAFE);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.ApprovalCallerNotOwnerNorApproved.selector));
        token.approve(address(0xBEEF), 5);
    }

    function test_revert_TransferFromUnOwned() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_revert_TransferFromWrongFrom() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.TransferFromIncorrectOwner.selector));
        token.transferFrom(address(0xFEED), address(0xBEEF), 5);
    }

    function test_revert_TransferFromToZero() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.TransferToZeroAddress.selector));
        token.transferFrom(address(this), address(0), 5);
    }

    function test_revert_TransferFromNotOwner() public {
        address minter = address(0xFEED);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.TransferFromIncorrectOwner.selector));
        token.transferFrom(address(0xCAFE), address(0xBEEF), 5);
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 5);
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 5, "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 5);
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 5, "testing 123");
    }

    function test_revert_SafeTransferFromToERC721RecipientWithWrongReturnData() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        address unsafeRecipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert(abi.encodeWithSelector(IERC721A.TransferToNonERC721ReceiverImplementer.selector));
        token.safeTransferFrom(address(this), unsafeRecipient, 5);
    }

    function test_revert_SafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        address minter = address(this);
        uint256 quantity = 10;

        token.mint(minter, quantity, "");

        address unsafeRecipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert(abi.encodeWithSelector(IERC721A.TransferToNonERC721ReceiverImplementer.selector));
        token.safeTransferFrom(address(this), unsafeRecipient, 5, "testing 123");
    }

    function test_revert_BalanceOfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721A.BalanceQueryForZeroAddress.selector));
        token.balanceOf(address(0));
    }

    function test_revert_OwnerOfUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721A.OwnerQueryForNonexistentToken.selector));
        token.ownerOf(1337);
    }
}
