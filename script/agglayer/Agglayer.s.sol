// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TestNFT} from "./TestNFT.sol";
import {console} from "forge-std/console.sol";
import {Role} from "src/Role.sol";
import {PolygonAgglayerCrossChain} from "src/module/token/crosschain/PolygonAgglayer.sol";
import {ERC20Base} from "src/core/token/ERC20Base.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

contract DeployTestNFT is Script {
    TestNFT public testNFT;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        testNFT = new TestNFT("TestNFT", "TNFT");
        console.log("TestNFT deployed to:", address(testNFT));

        vm.stopBroadcast();
    }
}

contract MintTestNFT is Script {
    TestNFT public testNFT;
    ERC20Base public testToken;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address testNFTAddress = vm.envAddress("TEST_NFT_ADDRESS");
        address testTokenAddress = vm.envAddress("TEST_TOKEN_ADDRESS");
        uint64 destinationChain = 2442;
        vm.startBroadcast(deployerPrivateKey);

        testNFT = TestNFT(testNFTAddress);
        testToken = ERC20Base(payable(testTokenAddress));
        
        OwnableRoles(testTokenAddress).grantRoles(deployerAddress, Role._MINTER_ROLE);
        testToken.mint(deployerAddress, 100, "");
        console.log("Minted test tokens to deployer");

        bytes memory extraArgs = abi.encode(address(0), false, testToken, 100);
        bytes memory payload = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,uint256)")),
            deployerAddress,
            1
        );

        PolygonAgglayerCrossChain(testTokenAddress).sendCrossChainTransaction(
            destinationChain,
            address(testNFT),
            payload,
            extraArgs
        );

        vm.stopBroadcast();
    }
}
