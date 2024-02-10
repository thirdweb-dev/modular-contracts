// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { TestPlus } from "../utils/TestPlus.sol";
import { EmptyExtensionERC721 } from "../mocks/EmptyExtension.sol";

import { CloneFactory } from "src/infra/CloneFactory.sol";
import { ERC721Core, ERC721Initializable } from "src/core/token/ERC721Core.sol";
import { IERC721 } from "src/interface/eip/IERC721.sol";
import { IERC721CustomErrors } from "src/interface/errors/IERC721CustomErrors.sol";
import { IERC721CoreCustomErrors } from "src/interface/errors/IERC721CoreCustomErrors.sol";
import { IExtension } from "src/interface/extension/IExtension.sol";
import { IInitCall } from "src/interface/common/IInitCall.sol";

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

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
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

    CloneFactory public cloneFactory;

    address public erc721Implementation;
    address public extensionProxyAddress;

    ERC721Core public token;

    function setUp() public {
        cloneFactory = new CloneFactory();

        erc721Implementation = address(new ERC721Core());
        extensionProxyAddress = cloneFactory.deployDeterministicERC1967(
            address(new EmptyExtensionERC721()),
            "",
            bytes32("salt")
        );

        vm.startPrank(admin);

        IInitCall.InitCall memory initCall;
        bytes memory data = abi.encodeWithSelector(
            ERC721Core.initialize.selector,
            initCall,
            new address[](0),
            admin,
            "Token",
            "TKN",
            "contractURI://"
        );
        token = ERC721Core(cloneFactory.deployProxyByImplementation(erc721Implementation, data, bytes32("salt")));
        token.installExtension(IExtension(extensionProxyAddress));

        vm.stopPrank();

        vm.label(address(token), "ERC721Core");
        vm.label(erc721Implementation, "ERC721CoreImpl");
        vm.label(admin, "Admin");
    }

    function testMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
    }

    function testMint() public {
        uint256 quantity = 10;
        token.mint(address(0xBEEF), quantity, "");

        assertEq(token.balanceOf(address(0xBEEF)), quantity);

        for (uint256 i = 0; i < quantity; i++) {
            assertEq(token.ownerOf(i), address(0xBEEF));
        }
    }

    function testBurn() public {
        uint256 quantity = 10;
        uint256 idToBurn = 5;

        token.mint(address(0xBEEF), quantity, "");

        vm.prank(address(0xBEEF));
        token.burn(idToBurn, "");

        assertEq(token.balanceOf(address(0xBEEF)), quantity - 1);

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotMinted.selector, idToBurn));
        token.ownerOf(idToBurn);
    }

    function testApprove() public {
        uint256 quantity = 10;
        uint256 idToApprove = 5;

        token.mint(address(this), quantity, "");

        token.approve(address(0xBEEF), idToApprove);

        assertEq(token.getApproved(idToApprove), address(0xBEEF));
    }

    function testApproveBurn() public {
        uint256 quantity = 10;
        uint256 idToBurn = 5;
        token.mint(address(this), quantity, "");

        token.approve(address(0xBEEF), idToBurn);

        token.burn(idToBurn, "");

        assertEq(token.balanceOf(address(this)), quantity - 1);
        assertEq(token.getApproved(idToBurn), address(0));

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotMinted.selector, idToBurn));
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

        token.mint(from, quantity, "");

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

        token.mint(address(this), quantity, "");

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

        token.mint(from, quantity, "");

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

        token.mint(from, quantity, "");

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

        token.mint(from, quantity, "");

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

        token.mint(from, quantity, "");

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
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721InvalidRecipient.selector));
        token.mint(address(0), 1, "");
    }

    function test_revert_BurnUnMinted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotMinted.selector, 10));
        token.burn(10, "");
    }

    function test_revert_DoubleBurn() public {
        token.mint(address(this), 5, "");

        token.burn(0, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotMinted.selector, 0));
        token.burn(0, "");
    }

    function test_revert_ApproveUnMinted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotApproved.selector, address(this), 1337));
        token.approve(address(0xBEEF), 1337);
    }

    function test_revert_ApproveUnAuthorized() public {
        token.mint(address(0xCAFE), 10, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotApproved.selector, address(this), 5));
        token.approve(address(0xBEEF), 5);
    }

    function test_revert_TransferFromUnOwned() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotOwner.selector, address(0xFEED), 1337));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function test_revert_TransferFromWrongFrom() public {
        token.mint(address(0xCAFE), 10, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotOwner.selector, address(0xFEED), 5));
        token.transferFrom(address(0xFEED), address(0xBEEF), 5);
    }

    function test_revert_TransferFromToZero() public {
        token.mint(address(this), 10, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721InvalidRecipient.selector));
        token.transferFrom(address(this), address(0), 5);
    }

    function test_revert_TransferFromNotOwner() public {
        token.mint(address(0xFEED), 10, "");

        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotOwner.selector, address(0xCAFE), 5));
        token.transferFrom(address(0xCAFE), address(0xBEEF), 5);
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        token.mint(address(this), 10, "");

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 5);
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        token.mint(address(this), 10, "");

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 5, "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        token.mint(address(this), 10, "");

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 5);
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        token.mint(address(this), 10, "");

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 5, "testing 123");
    }

    function test_revert_SafeTransferFromToERC721RecipientWithWrongReturnData() public {
        token.mint(address(this), 10, "");

        address unsafeRecipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721UnsafeRecipient.selector, unsafeRecipient));
        token.safeTransferFrom(address(this), unsafeRecipient, 5);
    }

    function test_revert_SafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        token.mint(address(this), 10, "");

        address unsafeRecipient = address(new WrongReturnDataERC721Recipient());
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721UnsafeRecipient.selector, unsafeRecipient));
        token.safeTransferFrom(address(this), unsafeRecipient, 5, "testing 123");
    }

    function test_revert_BalanceOfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721ZeroAddress.selector));
        token.balanceOf(address(0));
    }

    function test_revert_OwnerOfUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721CustomErrors.ERC721NotMinted.selector, 1337));
        token.ownerOf(1337);
    }
}
