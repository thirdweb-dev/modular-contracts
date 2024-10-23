// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Script} from "forge-std/Script.sol";

import {Module} from "src/Module.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {TransferableERC721} from "src/module/token/transferable/TransferableERC721.sol";

contract Core is ERC721Core {

    constructor(string memory name, string memory symbol, string memory contractURI, address owner)
        ERC721Core(name, symbol, contractURI, owner, new address[](0), new bytes[](0))
    {}

    // disable mint and approve callbacks for these tests
    function _beforeMint(address to, uint256 startTokenId, uint256 quantity, bytes calldata data) internal override {}
    function _beforeApproveForAll(address from, address to, bool approved) internal override {}

}

contract TransferableERC721Script is Script {

    Core public core;

    TransferableERC721 public transferableModule;

    function run() public {
        uint256 privateKey = vm.envUint("TEST_PRIVATE_KEY");
        address owner = vm.addr(privateKey);
        vm.startBroadcast(privateKey);

        core = new Core("test", "TEST", "", owner);
        transferableModule = new TransferableERC721();
        console.log("TransferableERC721 deployed to:", address(transferableModule));
        console.log("Core deployed to:", address(core));

        // install module
        core.installModule(address(transferableModule), "");

        // mint tokens
        core.mint(owner, 100, string(""), "");

        vm.stopBroadcast();
    }

}
