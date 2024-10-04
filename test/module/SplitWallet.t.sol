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
    address public recipient1 = address(0x4);
    address public recipient2 = address(0x5);

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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
                        Unit tests: distribute and withdraw
    //////////////////////////////////////////////////////////////*/

    function test_distribute_and_withdraw_ETH() public {
        // Deposit ETH to splitWallet
        vm.deal(splitWallet, 1 ether);

        // Check initial balances
        uint256 initialBalance1 = recipient1.balance;
        uint256 initialBalance2 = recipient2.balance;

        // Distribute ETH
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
        splitFeesCore.withdraw(recipient1, NATIVE_TOKEN_ADDRESS);

        vm.prank(recipient2);
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
        splitFeesCore.withdraw(recipient1, address(token));

        vm.prank(recipient2);
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

    function test_revert_notSplitFees() public {
        vm.expectRevert(abi.encodeWithSelector(SplitWallet.OnlySplitFees.selector));
        SplitWallet(splitWallet).transferETH(10 ether);

        vm.expectRevert(abi.encodeWithSelector(SplitWallet.OnlySplitFees.selector));
        SplitWallet(splitWallet).transferERC20(address(token), 10 ether);
    }

}
