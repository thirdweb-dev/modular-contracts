// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test, Vm} from "forge-std/Test.sol";

// Target contracts
import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";
import {Role} from "src/Role.sol";
import {SplitFeesCore} from "src/core/SplitFeesCore.sol";

import {SplitWallet} from "src/core/SplitWallet.sol";
import {SplitFeesModule} from "src/module/SplitFeesModule.sol";

import {ERC20} from "@solady/tokens/ERC20.sol";
import {ISplitWallet} from "src/interface/ISplitWallet.sol";
import {Split} from "src/libraries/Split.sol";

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

contract SplitFeesModuleTest is Test {

    SplitFeesCore public splitFeesCore;
    SplitFeesModule public splitFeesModule;

    MockCurrency public token;

    address public splitWallet;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    address public recipient1 = address(0x4);
    address public recipient2 = address(0x5);

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event SplitCreated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event SplitsUpdated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event SplitsDistributed(address indexed receiver, address token, uint256 amount);
    event SplitsWithdrawn(address indexed owner, address token, uint256 amount);

    function setUp() public {
        // Instantiate SplitFeesCore and install SplitFeesModule
        splitFeesCore = new SplitFeesCore(owner);
        splitFeesModule = new SplitFeesModule();

        vm.prank(owner);
        splitFeesCore.installModule(address(splitFeesModule), "");

        // Create a split using the module
        (address[] memory recipients, uint256[] memory allocations) = getRecipientsAndAllocations();

        vm.recordLogs();
        vm.prank(owner);
        SplitFeesModule(address(splitFeesCore)).createSplit(recipients, allocations, owner);

        // Retrieve the splitWallet address from the event logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 SplitCreatedTopic = keccak256("SplitCreated(address,address[],uint256[],address)");

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];
            if (log.topics[0] == SplitCreatedTopic) {
                // This is the SplitCreated event
                splitWallet = address(uint160(uint256(log.topics[1])));
                break;
            }
        }

        token = new MockCurrency();
    }

    function getRecipientsAndAllocations() public view returns (address[] memory, uint256[] memory) {
        address[] memory recipients = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        allocations[0] = 50;
        allocations[1] = 50;

        return (recipients, allocations);
    }

    /*//////////////////////////////////////////////////////////////
                        Unit tests: createSplit
    //////////////////////////////////////////////////////////////*/

    function test_state_createSplit() public {
        // Set up recipients and allocations
        (address[] memory recipients, uint256[] memory allocations) = getRecipientsAndAllocations();

        vm.recordLogs();
        vm.prank(owner);
        SplitFeesModule(address(splitFeesCore)).createSplit(recipients, allocations, owner);

        // Get the splitWallet address from the SplitCreated event
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 SplitCreatedTopic = keccak256("SplitCreated(address,address[],uint256[],address)");

        address newSplitWallet;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];
            if (log.topics[0] == SplitCreatedTopic) {
                // This is the SplitCreated event
                newSplitWallet = address(uint160(uint256(log.topics[1])));
                break;
            }
        }

        address splitFees = SplitWallet(newSplitWallet).splitFees();

        assertEq(splitFees, address(splitFeesCore), "splitWallet splitFees incorrect");
    }

    function test_revert_createSplit_TooFewRecipients() public {
        address[] memory recipients = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        recipients[0] = address(0x1);
        allocations[0] = 100;

        vm.prank(owner);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(SplitFeesModule.SplitFeesTooFewRecipients.selector));
        SplitFeesModule(address(splitFeesCore)).createSplit(recipients, allocations, owner);
    }

    function test_revert_createSplit_LengthMismatch() public {
        // Set up recipients and allocations with mismatched lengths
        address[] memory recipients = new address[](2);
        recipients[0] = address(0x1);
        recipients[1] = address(0x2);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 100;

        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(SplitFeesModule.SplitFeesLengthMismatch.selector));
        SplitFeesModule(address(splitFeesCore)).createSplit(recipients, allocations, owner);
    }

    /*//////////////////////////////////////////////////////////////
                        Unit tests: updateSplit
    //////////////////////////////////////////////////////////////*/

    function test_updateSplit() public {
        // Assume that createSplit has been called in setUp()
        // Now, we update the split

        address[] memory newRecipients = new address[](2);
        uint256[] memory newAllocations = new uint256[](2);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newAllocations[0] = 70;
        newAllocations[1] = 30;

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit SplitsUpdated(splitWallet, newRecipients, newAllocations, owner);
        SplitFeesModule(address(splitFeesCore)).updateSplit(splitWallet, newRecipients, newAllocations, owner);

        Split memory split = SplitFeesModule(address(splitFeesCore)).getSplit(splitWallet);

        assertEq(split.recipients, newRecipients, "Recipients should be updated");
        assertEq(split.allocations, newAllocations, "Allocations should be updated");
    }

    function test_revert_updateSplit_NotController() public {
        // Try to update split from unpermissioned actor

        address[] memory newRecipients = new address[](2);
        uint256[] memory newAllocations = new uint256[](2);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newAllocations[0] = 70;
        newAllocations[1] = 30;

        vm.prank(unpermissionedActor);
        vm.expectRevert(abi.encodeWithSelector(SplitFeesModule.SplitFeesNotController.selector));
        SplitFeesModule(address(splitFeesCore)).updateSplit(splitWallet, newRecipients, newAllocations, owner);
    }

    /*//////////////////////////////////////////////////////////////
                        Unit tests: distribute and withdraw
    //////////////////////////////////////////////////////////////*/

    function test_distribute_and_withdraw_ETH() public {
        // Deposit ETH to splitWallet
        vm.deal(splitWallet, 1 ether);

        // Check initial balances
        uint256 initialBalance1 = recipient1.balance;
        uint256 initialBalance2 = recipient2.balance;

        // Distribute ETH
        vm.expectEmit(true, true, true, true);
        emit SplitsDistributed(splitWallet, NATIVE_TOKEN_ADDRESS, 1 ether);
        splitFeesCore.distribute(splitWallet, NATIVE_TOKEN_ADDRESS);

        // After distribute, balances should be updated in the ERC6909 contract
        uint256 tokenId = uint256(uint160(NATIVE_TOKEN_ADDRESS));

        // Check that recipients have the correct balances
        uint256 balance1 = splitFeesCore.balanceOf(recipient1, tokenId);
        uint256 balance2 = splitFeesCore.balanceOf(recipient2, tokenId);

        assertEq(balance1, 0.5 ether, "Recipient1 should have 0.5 ether balance");
        assertEq(balance2, 0.5 ether, "Recipient2 should have 0.5 ether balance");

        // Now recipients can withdraw their balances
        vm.prank(recipient1);
        vm.expectEmit(true, true, true, true);
        emit SplitsWithdrawn(recipient1, NATIVE_TOKEN_ADDRESS, 0.5 ether);
        splitFeesCore.withdraw(recipient1, NATIVE_TOKEN_ADDRESS);

        vm.prank(recipient2);
        vm.expectEmit(true, true, true, true);
        emit SplitsWithdrawn(recipient2, NATIVE_TOKEN_ADDRESS, 0.5 ether);
        splitFeesCore.withdraw(recipient2, NATIVE_TOKEN_ADDRESS);

        // Check that recipients received ETH
        assertEq(recipient1.balance, initialBalance1 + 0.5 ether, "Recipient1 should have received 0.5 ether");
        assertEq(recipient2.balance, initialBalance2 + 0.5 ether, "Recipient2 should have received 0.5 ether");

        // Check that their balances in the ERC6909 contract are zero
        balance1 = splitFeesCore.balanceOf(recipient1, tokenId);
        balance2 = splitFeesCore.balanceOf(recipient2, tokenId);

        assertEq(balance1, 0, "Recipient1 should have zero balance after withdrawal");
        assertEq(balance2, 0, "Recipient2 should have zero balance after withdrawal");
    }

    function test_distribute_and_withdraw_ERC20() public {
        // Mint tokens to splitWallet
        uint256 amount = 1000 ether;
        token.mintTo(splitWallet, amount);

        // Check initial balances
        uint256 initialBalance1 = token.balanceOf(recipient1);
        uint256 initialBalance2 = token.balanceOf(recipient2);

        // Distribute ERC20 tokens
        vm.expectEmit(true, true, true, true);
        emit SplitsDistributed(splitWallet, address(token), amount);
        splitFeesCore.distribute(splitWallet, address(token));

        // After distribute, balances should be updated in the ERC6909 contract
        uint256 tokenId = uint256(uint160(address(token)));

        // Check that recipients have the correct balances
        uint256 balance1 = splitFeesCore.balanceOf(recipient1, tokenId);
        uint256 balance2 = splitFeesCore.balanceOf(recipient2, tokenId);

        assertEq(balance1, amount / 2, "Recipient1 should have half of the tokens");
        assertEq(balance2, amount / 2, "Recipient2 should have half of the tokens");

        // Now recipients can withdraw their balances
        vm.prank(recipient1);
        vm.expectEmit(true, true, true, true);
        emit SplitsWithdrawn(recipient1, address(token), amount / 2);
        splitFeesCore.withdraw(recipient1, address(token));

        vm.prank(recipient2);
        vm.expectEmit(true, true, true, true);
        emit SplitsWithdrawn(recipient2, address(token), amount / 2);
        splitFeesCore.withdraw(recipient2, address(token));

        // Check that recipients received tokens
        assertEq(token.balanceOf(recipient1), initialBalance1 + amount / 2, "Recipient1 should have received tokens");
        assertEq(token.balanceOf(recipient2), initialBalance2 + amount / 2, "Recipient2 should have received tokens");

        // Check that their balances in the ERC6909 contract are zero
        balance1 = splitFeesCore.balanceOf(recipient1, tokenId);
        balance2 = splitFeesCore.balanceOf(recipient2, tokenId);

        assertEq(balance1, 0, "Recipient1 should have zero balance after withdrawal");
        assertEq(balance2, 0, "Recipient2 should have zero balance after withdrawal");
    }

    function test_revert_withdraw_NothingToWithdraw() public {
        // Recipient tries to withdraw without any balance

        vm.prank(recipient1);
        vm.expectRevert(abi.encodeWithSelector(SplitFeesModule.SplitFeesNothingToWithdraw.selector));
        splitFeesCore.withdraw(recipient1, NATIVE_TOKEN_ADDRESS);
    }

    function test_revert_withdraw_Twice() public {
        // Deposit ETH to splitWallet
        vm.deal(splitWallet, 1 ether);

        // Distribute ETH
        splitFeesCore.distribute(splitWallet, NATIVE_TOKEN_ADDRESS);

        // Recipient1 withdraws
        vm.prank(recipient1);
        splitFeesCore.withdraw(recipient1, NATIVE_TOKEN_ADDRESS);

        // Recipient1 tries to withdraw again
        vm.prank(recipient1);
        vm.expectRevert(abi.encodeWithSelector(SplitFeesModule.SplitFeesNothingToWithdraw.selector));
        splitFeesCore.withdraw(recipient1, NATIVE_TOKEN_ADDRESS);
    }

    function test_distribute_withUpdatedSplit() public {
        // Deposit ETH to splitWallet
        vm.deal(splitWallet, 1 ether);

        // Update split
        address[] memory newRecipients = new address[](2);
        uint256[] memory newAllocations = new uint256[](2);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newAllocations[0] = 70;
        newAllocations[1] = 30;

        vm.prank(owner);
        SplitFeesModule(address(splitFeesCore)).updateSplit(splitWallet, newRecipients, newAllocations, owner);

        // Distribute ETH
        splitFeesCore.distribute(splitWallet, NATIVE_TOKEN_ADDRESS);

        // After distribute, balances should be updated in the ERC6909 contract
        uint256 tokenId = uint256(uint160(NATIVE_TOKEN_ADDRESS));

        // Check that recipients have the correct balances
        uint256 balance1 = splitFeesCore.balanceOf(recipient1, tokenId);
        uint256 balance2 = splitFeesCore.balanceOf(recipient2, tokenId);

        assertEq(balance1, 0.7 ether, "Recipient1 should have 0.7 ether balance");
        assertEq(balance2, 0.3 ether, "Recipient2 should have 0.3 ether balance");
    }

}
