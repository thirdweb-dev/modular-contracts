// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

// Test util
import { CloneFactory } from "src/infra/CloneFactory.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol"; 
import { MockBuggySimpleClaim } from "test/mocks/MockBuggySimpleClaim.sol";
import { TransferHook } from "test/mocks/TransferHook.sol";

// Target test contracts
import { IERC721 } from "src/interface/erc721/IERC721.sol";
import { ITokenHook } from "src/interface/extension/ITokenHook.sol";
import { ERC721Core, ERC721 } from "src/erc721/ERC721Core.sol";
import { ERC721SimpleClaim } from "src/erc721/hooks/ERC721SimpleClaim.sol";

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
        erc721.installHook(ITokenHook(address(simpleClaim)));

        vm.stopPrank();
    }

    function test_bits() public {

        for(uint256 i = 0; i < 256 ; i++) {
            assertEq(1 << i, 2 ** i);
        }
    }

    function test_mint() public {
        
        vm.deal(claimer, 0.5 ether);

        assertEq(claimer.balance, 0.5 ether);
        assertEq(admin.balance, 0);
        assertEq(erc721.balanceOf(claimer), 0);
        assertEq(simpleClaim.nextTokenIdToMint(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721.ERC721NotMinted.selector, 0)
        );
        erc721.ownerOf(0);

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        // Claim token
        vm.prank(claimer);
        erc721.mint{value: 0.1 ether}(claimer, 1, abi.encode(1, proofs));

        assertEq(claimer.balance, 0.4 ether);
        assertEq(admin.balance, 0.1 ether);
        assertEq(erc721.balanceOf(claimer), 1);
        assertEq(simpleClaim.nextTokenIdToMint(), 1);
        assertEq(erc721.ownerOf(0), claimer);

        assertEq(erc721.tokenURI(0), "https://example.com/0");
    }

    function test_transferHook() public {

        address recipient = address(0x456);
        vm.label(recipient, "Recipient");

        // Deploy transfer hook implementation contract
        TransferHook transferHook = new TransferHook(admin, false);

        vm.startPrank(admin);

        // Set transfer hook
        erc721.installHook(ITokenHook(address(transferHook)));
        assertEq(erc721.getHookImplementation(erc721.BEFORE_TRANSFER_FLAG()), address(transferHook));

        // Mint token
        ERC721SimpleClaim.ClaimCondition memory condition = ERC721SimpleClaim.ClaimCondition({
            price: 0 ether,
            availableSupply: 5,
            allowlistMerkleRoot: bytes32(0),
            saleRecipient: admin
        });
        simpleClaim.setClaimCondition(address(erc721), condition);
        erc721.mint(claimer, 1, abi.encode(1, ""));
        
        vm.stopPrank();

        assertEq(erc721.ownerOf(0), claimer);

        // Claimer does not have transfer role, so transfer should fail
        assertEq(transferHook.isTransferrable(), false);

        vm.expectRevert("restricted to TRANSFER_ROLE holders");
        vm.prank(claimer);
        
        erc721.transferFrom(claimer, recipient, 0);

        // Transfer succeeds once transfer role is granted to claimer 
        vm.startPrank(admin);
        transferHook.grantRole(claimer, transferHook.TRANSFER_ROLE_BITS());
        vm.stopPrank();

        vm.prank(claimer);
        erc721.transferFrom(claimer, recipient, 0);
        
        assertEq(erc721.ownerOf(0), recipient);
    }

    function test_claimContractUpgrade() public {
        vm.deal(claimer, 0.5 ether);
        
        // NOTE: proxy admin is different from ERC721 admin
        address proxyAdmin = address(0x7567);

        // Deploy `MockBuggySimpleClaim` behind an upgradeable proxy
        address proxySimpleClaim = address(
            new TransparentUpgradeableProxy(
                address(new MockBuggySimpleClaim()),
                proxyAdmin,
                ""
            )
        );

        // Set this contract as minter on ERC721 Core
        vm.startPrank(admin);
        erc721.uninstallHook(ITokenHook(simpleClaim));
        erc721.installHook(ITokenHook(proxySimpleClaim));
        vm.stopPrank();

        // Set claim conditions and claim one token

        // Set claim condition
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

        vm.prank(admin);
        ERC721SimpleClaim(proxySimpleClaim).setClaimCondition(address(erc721), condition);

        // Claim token
        vm.expectRevert(
            abi.encodeWithSelector(IERC721.ERC721NotMinted.selector, 0)
        );
        erc721.ownerOf(0);

        string[] memory inputsProof = new string[](2);
        inputsProof[0] = "node";
        inputsProof[1] = "test/scripts/getProof.ts";
        
        bytes memory resultProof = vm.ffi(inputsProof);
        bytes32[] memory proofs = abi.decode(resultProof, (bytes32[]));

        vm.prank(claimer);
        erc721.mint{value: 0.1 ether}(claimer, 1, abi.encode(1, proofs));

        assertEq(erc721.ownerOf(0), claimer);

        // But BUG: the claim condition supply is not decremented!
        (,uint256 availableSupply,,) = ERC721SimpleClaim(proxySimpleClaim).claimCondition(address(erc721));
        assertEq(availableSupply, 5);
        
        // Perform upgrade
        vm.prank(proxyAdmin);
        TransparentUpgradeableProxy(payable(proxySimpleClaim)).upgradeTo(address(simpleClaim));

        // Claim condition supply is already set, since state is unchanged after logic upgrade
        (,availableSupply,,) = ERC721SimpleClaim(proxySimpleClaim).claimCondition(address(erc721));
        assertEq(availableSupply, 5);

        // But the bug is fixed, so the supply is decremented upon a new claim
        vm.prank(claimer);
        erc721.mint{value: 0.1 ether}(claimer, 1, abi.encode(1, proofs));

        assertEq(erc721.ownerOf(1), claimer);
        (,availableSupply,,) = ERC721SimpleClaim(proxySimpleClaim).claimCondition(address(erc721));
        assertEq(availableSupply, 4);
    }
}
