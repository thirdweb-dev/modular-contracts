// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TestPlus} from "../utils/TestPlus.sol";
import {EmptyHookERC20} from "../mocks/EmptyHook.sol";

import {CloneFactory} from "src/infra/CloneFactory.sol";
import {ERC20Core, ERC20Initializable} from "src/core/token/ERC20Core.sol";
import {IERC20} from "src/interface/eip/IERC20.sol";
import {IHook} from "src/interface/hook/IHook.sol";
import {IInitCall} from "src/interface/common/IInitCall.sol";

contract ERC20CoreTest is Test, TestPlus {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    struct _TestTemps {
        address owner;
        address to;
        uint256 amount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 privateKey;
        uint256 nonce;
    }

    function _testTemps() internal returns (_TestTemps memory t) {
        (t.owner, t.privateKey) = _randomSigner();
        t.to = _randomNonZeroAddress();
        t.amount = _random();
        t.deadline = _random();
    }

    // Participants
    address public admin = address(0x123);

    // Test util
    CloneFactory public cloneFactory;

    // Target test contracts
    address public erc20Implementation;
    address public hookProxyAddress;

    ERC20Core public token;

    function setUp() public {
        cloneFactory = new CloneFactory();

        erc20Implementation = address(new ERC20Core());
        hookProxyAddress = cloneFactory.deployDeterministicERC1967(
            address(new EmptyHookERC20()),
            "",
            bytes32("salt")
        );

        vm.startPrank(admin);

        IInitCall.InitCall memory initCall;
        bytes memory data = abi.encodeWithSelector(
            ERC20Core.initialize.selector,
            initCall,
            new address[](0),
            admin,
            "Token",
            "TKN",
            "contractURI://"
        );
        token = ERC20Core(
            cloneFactory.deployProxyByImplementation(
                erc20Implementation,
                data,
                bytes32("salt")
            )
        );
        token.installHook(IHook(hookProxyAddress), bytes(""));

        vm.stopPrank();

        vm.label(address(token), "ERC20Core");
        vm.label(erc20Implementation, "ERC20CoreImpl");
        vm.label(admin, "Admin");
    }

    function testMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
    }

    function testMint() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(0xBEEF), 1e18);
        token.mint(address(0xBEEF), 1e18, "");

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1e18, "");

        vm.startPrank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0xBEEF), address(0), 0.9e18);
        token.burn(0.9e18, "");
        vm.stopPrank();

        assertEq(token.totalSupply(), 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), address(0xBEEF), 1e18);
        assertTrue(token.approve(address(0xBEEF), 1e18));

        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        token.mint(address(this), 1e18, "");

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), address(0xBEEF), 1e18);
        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1e18, "");

        vm.prank(from);
        token.approve(address(this), 1e18);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, address(0xBEEF), 1e18);
        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1e18, "");

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPermit() public {
        _TestTemps memory t = _testTemps();
        t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        _permit(t);

        _checkAllowanceAndNonce(t);
    }

    function testTransferInsufficientBalanceReverts() public {
        token.mint(address(this), 0.9e18, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20TransferAmountExceedsBalance.selector,
                1e18,
                0.9e18
            )
        );
        token.transfer(address(0xBEEF), 1e18);
    }

    function testTransferFromInsufficientAllowanceReverts() public {
        address from = address(0xABCD);

        token.mint(from, 1e18, "");

        vm.prank(from);
        token.approve(address(this), 0.9e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20InsufficientAllowance.selector,
                0.9e18,
                1e18
            )
        );
        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testTransferFromInsufficientBalanceReverts() public {
        address from = address(0xABCD);

        token.mint(from, 0.9e18, "");

        vm.prank(from);
        token.approve(address(this), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20TransferAmountExceedsBalance.selector,
                1e18,
                0.9e18
            )
        );
        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), to, amount);
        token.mint(to, amount, "");

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(to), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        vm.assume(from != address(0));
        burnAmount = _bound(burnAmount, 0, mintAmount);

        token.mint(from, mintAmount, "");

        vm.startPrank(from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, address(0), burnAmount);
        token.burn(burnAmount, "");
        vm.stopPrank();

        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        vm.assume(to != address(0));
        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
    }

    function testTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        token.mint(address(this), amount, "");

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), to, amount);
        assertTrue(token.transfer(to, amount));
        assertEq(token.totalSupply(), amount);

        if (address(this) == to) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testTransferFrom(
        address spender,
        address from,
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        vm.assume(
            spender != address(0) && from != address(0) && to != address(0)
        );
        amount = _bound(amount, 0, approval);

        token.mint(from, amount, "");
        assertEq(token.balanceOf(from), amount);

        vm.prank(from);
        token.approve(spender, approval);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        assertEq(token.totalSupply(), amount);

        if (approval == type(uint256).max) {
            assertEq(token.allowance(from, spender), approval);
        } else {
            assertEq(token.allowance(from, spender), approval - amount);
        }

        if (from == to) {
            assertEq(token.balanceOf(from), amount);
        } else {
            assertEq(token.balanceOf(from), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testPermit(uint256) public {
        _TestTemps memory t = _testTemps();
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        _permit(t);

        _checkAllowanceAndNonce(t);
    }

    function _checkAllowanceAndNonce(_TestTemps memory t) internal {
        assertEq(token.allowance(t.owner, t.to), t.amount);
        assertEq(token.nonces(t.owner), t.nonce + 1);
    }

    function testBurnInsufficientBalanceReverts(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        vm.assume(to != address(0));
        if (mintAmount == type(uint256).max) mintAmount--;
        burnAmount = _bound(burnAmount, mintAmount + 1, type(uint256).max);

        token.mint(to, mintAmount, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20TransferAmountExceedsBalance.selector,
                burnAmount,
                mintAmount
            )
        );
        vm.prank(to);
        token.burn(burnAmount, "");
    }

    function testTransferInsufficientBalanceReverts(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        vm.assume(to != address(0));
        if (mintAmount == type(uint256).max) mintAmount--;
        sendAmount = _bound(sendAmount, mintAmount + 1, type(uint256).max);

        token.mint(address(this), mintAmount, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20TransferAmountExceedsBalance.selector,
                sendAmount,
                mintAmount
            )
        );
        token.transfer(to, sendAmount);
    }

    function testTransferFromInsufficientAllowanceReverts(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        vm.assume(to != address(0));
        if (approval == type(uint256).max) approval--;
        amount = _bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        token.mint(from, amount, "");

        vm.prank(from);
        token.approve(address(this), approval);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20InsufficientAllowance.selector,
                approval,
                amount
            )
        );
        token.transferFrom(from, to, amount);
    }

    function testTransferFromInsufficientBalanceReverts(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        vm.assume(to != address(0));
        if (mintAmount == type(uint256).max) mintAmount--;
        sendAmount = _bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        token.mint(from, mintAmount, "");

        vm.prank(from);
        token.approve(address(this), sendAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Initializable.ERC20TransferAmountExceedsBalance.selector,
                sendAmount,
                mintAmount
            )
        );
        token.transferFrom(from, to, sendAmount);
    }

    function testPermitBadNonceReverts() public {
        _TestTemps memory t = _testTemps();

        t.nonce = _random();

        _signPermit(t);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20Core.ERC20PermitInvalidSigner.selector)
        );
        token.permit(t.owner, t.to, t.amount, t.deadline, t.v, t.r, t.s);
    }

    function testPermitBadDeadlineReverts() public {
        _TestTemps memory t = _testTemps();
        if (t.deadline == type(uint256).max) t.deadline--;
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20Core.ERC20PermitInvalidSigner.selector)
        );
        t.deadline += 1;
        token.permit(t.owner, t.to, t.amount, t.deadline, t.v, t.r, t.s);
    }

    function testPermitPastDeadlineReverts() public {
        _TestTemps memory t = _testTemps();
        t.deadline = _bound(t.deadline, 0, block.timestamp - 1);

        _signPermit(t);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Core.ERC20PermitDeadlineExpired.selector
            )
        );
        token.permit(t.owner, t.to, t.amount, t.deadline, t.v, t.r, t.s);
    }

    function testPermitReplayReverts() public {
        _TestTemps memory t = _testTemps();
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        token.permit(t.owner, t.to, t.amount, t.deadline, t.v, t.r, t.s);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Core.ERC20PermitInvalidSigner.selector)
        );
        token.permit(t.owner, t.to, t.amount, t.deadline, t.v, t.r, t.s);
    }

    function _signPermit(_TestTemps memory t) internal view {
        bytes32 innerHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                t.owner,
                t.to,
                t.amount,
                t.nonce,
                t.deadline
            )
        );
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 outerHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, innerHash)
        );
        (t.v, t.r, t.s) = vm.sign(t.privateKey, outerHash);
    }

    function _expectPermitEmitApproval(_TestTemps memory t) internal {
        vm.expectEmit(true, true, true, true);
        emit Approval(t.owner, t.to, t.amount);
    }

    function _permit(_TestTemps memory t) internal {
        address token_ = address(token);
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(sub(t, 0x20))
            mstore(sub(t, 0x20), 0xd505accf)
            pop(call(gas(), token_, 0, sub(t, 0x04), 0xe4, 0x00, 0x00))
            mstore(sub(t, 0x20), m)
        }
    }
}
