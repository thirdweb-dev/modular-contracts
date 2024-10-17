pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "lib/forge-std/src/console.sol";

import {ERC20Core} from "src/core/token/ERC20Core.sol";

import {SuperChainBridge} from "./SuperChainBridge.sol";
import {SuperChainInterop} from "src/module/token/crosschain/SuperChainInterop.sol";

contract Core is ERC20Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner
    ) payable ERC20Core(name, symbol, contractURI, owner, new address[](0), new bytes[](0)) {} 

    // disable mint callbacks for this script
    function _beforeMint(address to, uint256 amount, bytes calldata data) internal override {}

}

contract SuperChainInteropScript is Script {

    Core public core;
    SuperChainInterop public superchainInterop;
    SuperChainBridge public superchainBridge;
    address internal constant L2_TO_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000023;

    function run() external {
        uint256 testPrivateKey = vm.envUint("TEST_PRIVATE_KEY");
        address testAddress = vm.addr(testPrivateKey);
        vm.startBroadcast(testPrivateKey);

        // setup bridge and ERC-20 core
        superchainBridge = SuperChainBridge(0x6BF0d7B06930e016A9c03627c5BdE157cEfA1a47);
        core = Core(payable(0x6f7116d27F6fAE3986bdD05652EC22232B1DDAd7));
        console.log("SuperChainERC20 and Bridge setup");

        // mint tokens
        core.mint(testAddress, 10 ether, "");
        console.log("Tokens minted to test address: ", core.balanceOf(testAddress));

        // sendERC20
        superchainBridge.sendERC20(address(core), testAddress, 10 ether, 902);

        vm.stopBroadcast();
    }

}
