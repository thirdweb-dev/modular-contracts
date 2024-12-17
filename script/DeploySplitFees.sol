pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "lib/forge-std/src/console.sol";

import {SplitFeesCore} from "src/core/SplitFeesCore.sol";
import {SplitFeesModule} from "src/module/SplitFeesModule.sol";

contract DeploySplitFeesScript is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        address[] memory modules = new address[](1);
        bytes[] memory moduleData = new bytes[](1);
        modules[0] = address(new SplitFeesModule());
        moduleData[0] = "";

        SplitFeesCore splitFeesCore = new SplitFeesCore(deployerAddress, modules, moduleData);

        console.log("SplitFeesCore deployed: ", address(splitFeesCore));
        console.log("Split Wallet implementation: ", splitFeesCore.splitWalletImplementation());

        vm.stopBroadcast();
    }

}
