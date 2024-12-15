pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "lib/forge-std/src/console.sol";
import {SplitFeesCore} from "src/core/SplitFeesCore.sol";

import {SplitWallet} from "src/core/SplitWallet.sol";
import {SplitFeesModule} from "src/module/SplitFeesModule.sol";

contract DeployTWCloneFactoryScript is Script {

    address createX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    SplitFeesCore splitCore;
    SplitFeesModule splitModule;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encode("thirdweb-1"));

        splitCore = new SplitFeesCore{salt: salt}(deployerAddress, new address[](0), new bytes[](0));
        splitModule = new SplitFeesModule();
        console.log("split core deployed: ", address(splitCore));
        console.log("split module deployed: ", address(splitModule));

        splitCore.installModule(address(splitModule), new bytes(0));
        console.log("split module installed");

        vm.stopBroadcast();
    }

}
