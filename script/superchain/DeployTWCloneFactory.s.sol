pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "lib/forge-std/src/console.sol";
import {TWCloneFactoryV2} from "src/TWCloneFactory.sol";
import {SuperChainInterop} from "src/module/token/crosschain/SuperChainInterop.sol";

interface ICreateX {

    function deployCreate2(bytes32 salt, bytes memory initCode) external returns (address newContract);

}

contract DeployTWCloneFactoryScript is Script {

    address createX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function deployDeterministic(bytes32 salt, bytes memory creationCode) public returns (address) {
        address deployedAddress;

        // Deploy using CREATE2
        assembly {
            deployedAddress := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        require(deployedAddress != address(0), "CREATE2 failed");

        return deployedAddress;
    }

    function run() external {
        uint256 testPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(testPrivateKey);

        bytes32 salt;
        bytes memory initCode = abi.encodePacked(type(TWCloneFactoryV2).creationCode);

        address twCloneFactory = ICreateX(createX).deployCreate2(salt, initCode);
        console.log("TWCloneFactory deployed: ", twCloneFactory);

        vm.stopBroadcast();
    }

}
