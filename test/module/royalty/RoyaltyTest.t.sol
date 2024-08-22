// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import "./RoyaltyUtils.sol";
import {Test, console} from "forge-std/Test.sol";

// Target contract

import {ModularModule} from "src/ModularModule.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {CreatorTokenTransferValidator} from
    "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidator.sol";
import {Role} from "src/Role.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {MintableERC721} from "src/module/token/minting/MintableERC721.sol";
import {RoyaltyERC721} from "src/module/token/royalty/RoyaltyERC721.sol";

contract RoyaltyERC721Test is Test {

    ERC721Core public core;

    RoyaltyERC721 public royaltyModule;
    MintableERC721 public mintableModule;
    CreatorTokenTransferValidator public transferValidator;

    address public owner = address(0x1);

    address SEAPORT = 0x00000000006c3852cbEf3e08E8dF289169EdE581;
    address SEAPORT_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 20_585_576);

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        royaltyModule = new RoyaltyERC721();
        mintableModule = new MintableERC721();

        // install module
        bytes memory royaltyInitializeData = royaltyModule.encodeBytesOnInstall(owner, 100, address(0));
        bytes memory mintableInitializeData = mintableModule.encodeBytesOnInstall(owner);

        // install module
        vm.startPrank(owner);
        core.installModule(address(royaltyModule), royaltyInitializeData);
        core.installModule(address(mintableModule), mintableInitializeData);
        vm.stopPrank();

        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);

        // set up transfer validator
        transferValidator = CreatorTokenTransferValidator(0x721C0078c2328597Ca70F5451ffF5A7B38D4E947);
    }

    function test_setTransferValidatorPolicies() public {
        vm.startPrank(owner);
        transferValidator.setTransferSecurityLevelOfCollection(address(core), 3, false, false, false);
        uint120 listId = transferValidator.createList("testListRoyalty");
        address[] memory list = new address[](2);
        list[0] = address(SEAPORT);
        list[1] = address(SEAPORT_CONDUIT);
        transferValidator.addAccountsToWhitelist(listId, list);
        transferValidator.applyListToCollection(address(core), listId);

        address[] memory whitelistedAccounts = transferValidator.getWhitelistedAccountsByCollection(address(core));

        assertEq(whitelistedAccounts.length, 2);
        assertEq(whitelistedAccounts[0], SEAPORT);
        assertEq(whitelistedAccounts[1], SEAPORT_CONDUIT);
    }

}
