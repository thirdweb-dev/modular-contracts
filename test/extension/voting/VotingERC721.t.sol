// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {VotingERC721, VotingStorage} from "src/extension/token/voting/VotingERC721.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

contract BaseTest is Test {
    ERC721Core public core;
    VotingERC721 public extensionImplementation;

    // Signature vars
    bytes32 internal typehashDelegation;
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    bytes32 internal typehashEip712;
    bytes32 internal domainSeparator;

    uint256 ownerPrivateKey = 1;
    address public owner;

    uint256 voter1PrivateKey = 2;
    address public voter1;

    uint256 voter2PrivateKey = 3;
    address public voter2;

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        voter1 = vm.addr(voter1PrivateKey);
        voter2 = vm.addr(voter2PrivateKey);

        address[] memory extensions;
        bytes[] memory extensionData;

        core = new ERC721Core("VotingNFT", "VOTE", "", owner, extensions, extensionData);
        extensionImplementation = new VotingERC721();

        // install extension
        vm.prank(owner);
        core.installExtension(address(extensionImplementation), "");

        // Setup signature vars
        typehashDelegation = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
        nameHash = keccak256(bytes("VotingERC721"));
        versionHash = keccak256(bytes("1"));
        typehashEip712 = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        domainSeparator = keccak256(abi.encode(typehashEip712, nameHash, versionHash, block.chainid, address(core)));
    }

    function extension() internal returns (VotingERC721) {
        return VotingERC721(address(core));
    }
}

/*//////////////////////////////////////////////////////////////
                    Tests: Callback Functions
//////////////////////////////////////////////////////////////*/
/**
 * @dev 2 most common scenarios for both minting and burning:
 * 1. user mints (or burns) then delegates
 * 2. user delegates then mints (or burns)
 *
 * In the first case, there are no votes distributed until the votes have been delegated
 * In the second case, the votes are distributed immediately upon minting
 * regardless, votes will not be distributed until explcitly delegated
 */
contract CallbackTests is BaseTest {
    function test_beforeMintERC721_state() public {
        vm.startPrank(voter1);
        uint256 initialSupply = extension().getTotalSupply();
        extension().delegate(voter1);
        core.mint(voter1, 1, "");

        assertEq(extension().getTotalSupply(), initialSupply + 1, "Total supply should increase");
        assertEq(extension().getVotes(voter1), 1, "Voter should have 1 vote");
    }

    function test_beforeTransferERC721_state() public {
        vm.startPrank(voter2);
        extension().delegate(voter2);
        vm.startPrank(voter1);
        extension().delegate(voter1);

        core.mint(voter1, 1, "");
        core.transferFrom(voter1, voter2, 0);

        assertEq(extension().getVotes(voter1), 0, "Sender should have 0 votes");
        assertEq(extension().getVotes(voter2), 1, "Recipient should have 1 vote");
    }

    function test_beforeBurnERC721_state() public {
        vm.startPrank(voter1);
        extension().delegate(voter1);
        core.mint(voter1, 1, "");
        core.burn(0, "");

        assertEq(extension().getTotalSupply(), 0, "Total supply should decrease");
        assertEq(extension().getVotes(voter1), 0, "Voter should have 0 votes after burn");
    }
}

/*//////////////////////////////////////////////////////////////
                    Tests: Clock Functions
//////////////////////////////////////////////////////////////*/
contract ClockTests is BaseTest {
    function test_clock_state() public {
        assertEq(extension().clock(), uint48(block.timestamp), "Clock should return current timestamp");
    }

    function test_CLOCK_MODE_state() public {
        assertEq(extension().CLOCK_MODE(), "mode=blocknumber&from=default", "CLOCK_MODE should return correct string");
    }
}

/*//////////////////////////////////////////////////////////////
                    Tests: Voting Power Functions
//////////////////////////////////////////////////////////////*/
contract VotingTests is BaseTest {
    function test_getVotes_state() public {
        vm.startPrank(voter1);
        extension().delegate(voter1);
        core.mint(voter1, 2, "");
        assertEq(extension().getVotes(voter1), 2, "getVotes should return correct vote count");
    }

    function test_getPastVotes_state() public {
        vm.startPrank(voter1);
        extension().delegate(voter1);
        core.mint(voter1, 1, "");
        uint256 mintTimestamp = block.timestamp;

        vm.warp(mintTimestamp + 1);
        core.mint(voter1, 1, "");

        assertEq(
            extension().getPastVotes(voter1, mintTimestamp),
            1,
            "getPastVotes should return correct historical vote count"
        );
    }

    function test_getPastVotes_revert_futureLookup() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                VotingERC721.InvalidFutureLookup.selector, block.timestamp + 1, uint48(block.timestamp)
            )
        );
        extension().getPastVotes(voter1, block.timestamp + 1);
    }

    function test_getPastTotalSupply_state() public {
        vm.startPrank(voter1);
        core.mint(voter1, 1, "");
        uint256 mintTimestamp = block.timestamp;

        vm.warp(mintTimestamp + 1);
        core.mint(voter1, 1, "");

        assertEq(
            extension().getPastTotalSupply(mintTimestamp),
            1,
            "getPastTotalSupply should return correct historical total supply"
        );
    }

    function test_getPastTotalSupply_revert_futureLookup() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                VotingERC721.InvalidFutureLookup.selector, block.timestamp + 1, uint48(block.timestamp)
            )
        );
        extension().getPastTotalSupply(block.timestamp + 1);
    }

    function test_getTotalSupply_state() public {
        core.mint(voter1, 2, "");
        core.mint(voter2, 3, "");
        assertEq(extension().getTotalSupply(), 5, "getTotalSupply should return correct total supply");
    }
}

/*//////////////////////////////////////////////////////////////
                    Tests: Delegation Functions
//////////////////////////////////////////////////////////////*/
contract delegateTests is BaseTest {
    function test_delegates_state() public {
        core.mint(voter1, 1, "");
        vm.prank(voter1);
        extension().delegate(voter2);
        assertEq(extension().delegates(voter1), voter2, "delegates should return correct delegate");
    }

    function test_delegate_state() public {
        core.mint(voter1, 1, "");
        vm.prank(voter1);
        extension().delegate(voter2);
        assertEq(extension().getVotes(voter2), 1, "delegate should transfer voting power");
        assertEq(extension().getVotes(voter1), 0, "delegate should remove voting power from delegator");
    }

    function test_delegateBySig_state() public {
        core.mint(voter1, 1, "");
        uint256 nonce = extension().nonces(voter1);
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(typehashDelegation, voter2, nonce, expiry));

        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PrivateKey, typedDataHash);

        extension().delegateBySig(voter2, nonce, expiry, v, r, s);
        assertEq(extension().delegates(voter1), voter2, "delegateBySig should set correct delegate");
        assertEq(extension().getVotes(voter2), 1, "delegateBySig should transfer voting power");
    }

    function test_delegateBySig_revert_expiredSignature() public {
        core.mint(voter1, 1, "");
        uint256 nonce = extension().nonces(voter1);
        uint256 expiry = block.timestamp - 1; // Expired

        bytes32 structHash = keccak256(abi.encode(typehashDelegation, voter2, nonce, expiry));

        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voter1PrivateKey, typedDataHash);

        vm.expectRevert(abi.encodeWithSelector(VotingERC721.VotesExpiredSignature.selector, expiry));
        extension().delegateBySig(voter2, nonce, expiry, v, r, s);
    }
}
