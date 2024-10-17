
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

contract SuperChainERC20SetupScript is Script {

    SuperChainInterop public superchainInterop;
    address internal constant L2_TO_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000023;
   
    function deployDeterministic(bytes32 salt, bytes memory creationCode, bytes memory encodedArgs) public returns (address) {
        address deployedAddress;

        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, encodedArgs);

        // Deploy using CREATE2
        assembly {
            deployedAddress := create2(
                0, 
                add(creationCodeWithArgs, 0x20), 
                mload(creationCodeWithArgs), 
                salt
            )
        }
        
        require(deployedAddress != address(0), "CREATE2 failed");

        return deployedAddress;
    }

    function run() external {
        uint256 testPrivateKey = vm.envUint("TEST_PRIVATE_KEY");
        address testAddress = vm.addr(testPrivateKey);
        vm.startBroadcast(testPrivateKey);

        bytes32 salt = keccak256("thirdweb");

        // deploy superchain bridge
        address superchainBridge = deployDeterministic(salt, type(SuperChainBridge).creationCode, abi.encode(L2_TO_L2_CROSS_DOMAIN_MESSENGER));
        console.log("SuperChainBridge deployed: ", address(superchainBridge));

        // deploy core and superchainInterop module
        superchainInterop = new SuperChainInterop();
        console.log("SuperChainInterop deployed: ", address(superchainInterop));
        
        address core = deployDeterministic(salt, type(Core).creationCode, abi.encode("test", "TEST", "", testAddress));
        console.log("Core deployed: ", core);

        // install module
        bytes memory encodedInstallParams = superchainInterop.encodeBytesOnInstall(address(superchainBridge));
        Core(payable(core)).installModule(address(superchainInterop), encodedInstallParams);
        console.log("SuperChainInterop installed");

        vm.stopBroadcast();
    }

}
