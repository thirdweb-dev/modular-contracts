// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

// Test util
import { CloneFactory } from "src/infra/CloneFactory.sol";

// Target test contracts
import { ERC721Core } from "src/erc721/ERC721Core.sol";
import { ERC721SimpleClaim } from "src/erc721/ERC721SimpleClaim.sol";

/**
 *  This test showcases how users would use ERC-721 contracts on the thirdweb platform.
 *
 *  1. All users deploy a minimal clone of the `ERC721Core` contract.
 *
 *      - Minting: an address holding the `MINTER_ROLE` can call into the `mint(address to)` function to mint new tokens.
 *                 Tokens are minted with sequential tokenIds starting from zero.
 *
 *      - Token Metadata/URI: when a token is minted, the `ERC721Core` contract stores the address that performed the mint call.
 *                            By default, `tokenURI(id)` will return the URI for the token stored on the minter contract. If the minter
 *                            is a non-contract OR a URI has been stored locally on the contract, that local URI will be returned instead.
 *
 *  2. `ERC721SimpleClaim` is an example of a claim mechanism contract. It lets an admin of a given `ERC721Core` contract set claim
 *      conditions for that contract. Users can then claim tokens from that `ERC721Core` contract by calling `claim(address _token)`.
 *      To enable this flow, the `ERC721Core` contract's admin grants the `MINTER_ROLE` to the `ERC721SimpleClaim` contract.
 *
 *  3. `ERC721SimpleClaim` also returns the default for the tokens it mints on the `ERC721Core` contract. The admin of the core contract can
 *      set the token metadata for that contract's tokens on the minter contract.
 *
 *  NOTE: The `ERC721SimpleClaim` contract that the `ERC721Core` contract interacts with can be swapped at runtime
 *        for whatever reasons -- enabling new claim mechanics, storing metadata differently, bug fixes, etc.
 */

contract ERC721Test is Test {

    // Actors
    address public admin = address(0x123);
    address public claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Test util
    CloneFactory public cloneFactory;

    // Target test contracts
    ERC721Core public erc721;
    ERC721SimpleClaim public simpleClaim;

    function setUp() public {

        // Setup contracts
        cloneFactory = new CloneFactory();

        simpleClaim = new ERC721SimpleClaim();
        
        address implementation = address(new ERC721Core());
        bytes memory data = abi.encodeWithSelector(ERC721Core.initialize.selector, admin, "Test", "TST");
        erc721 = ERC721Core(
            cloneFactory.deployProxyByImplementation(implementation, data, bytes32("salt"))
        );

        vm.label(address(erc721), "ERC721");
        vm.label(address(simpleClaim), "ERC721SimpleClaim");
        vm.label(admin, "Admin");
        vm.label(claimer, "Claimer");

        vm.startPrank(admin);
        
        // Admin sets up token metadata.
        simpleClaim.setBaseURI(address(erc721), "https://example.com/");

        // Admin sets up claim conditions.
        
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

        ERC721SimpleClaim.ClaimCondition memory condition = ERC721SimpleClaim.ClaimCondition({
            price: 0.1 ether,
            availableSupply: 5,
            allowlistMerkleRoot: root,
            saleRecipient: admin
        });

        simpleClaim.setClaimCondition(address(erc721), condition);

        // Set `ERC721SimpleClaim` contract as minter
        erc721.setMinter(address(simpleClaim));

        vm.stopPrank();
    }

    function test_claim() public {
        
        vm.deal(claimer, 0.5 ether);

        assertEq(claimer.balance, 0.5 ether);
        assertEq(admin.balance, 0);
        assertEq(erc721.balanceOf(claimer), 0);
        assertEq(erc721.nextTokenIdToMint(), 0);
        vm.expectRevert("NOT_MINTED");
        erc721.ownerOf(0);

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        // Claim token
        vm.prank(claimer);
        simpleClaim.claim{value: 0.1 ether}(address(erc721), proofs);

        assertEq(claimer.balance, 0.4 ether);
        assertEq(admin.balance, 0.1 ether);
        assertEq(erc721.balanceOf(claimer), 1);
        assertEq(erc721.nextTokenIdToMint(), 1);
        assertEq(erc721.ownerOf(0), claimer);

        assertEq(erc721.tokenURI(0), "https://example.com/0");
    }
}
