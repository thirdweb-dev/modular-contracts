// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TestNFT} from "./TestNFT.sol";
import {console} from "forge-std/console.sol";
import {Role} from "src/Role.sol";
import {PolygonAgglayerCrossChain} from "src/module/token/crosschain/PolygonAgglayer.sol";
import {ERC20Core} from "src/core/token/ERC20Core.sol";
import {MintableERC20} from "src/module/token/minting/MintableERC20.sol";
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
    MintableERC20 public mintableModule;
    PolygonAgglayerCrossChain public polygonAgglayer;
    ERC20Core public core;

    address agglayerBridgeExtension = 0x2311BFA86Ae27FC10E1ad3f805A2F9d22Fc8a6a1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        // address coreAddress = vm.envAddress("TEST_TOKEN_ADDRESS");
        address testNFTAddress = vm.envAddress("TEST_NFT_ADDRESS");
        uint64 destinationChain = 2442;
        vm.startBroadcast(deployerPrivateKey);

        address[] memory modules = new address[](2);
        bytes[] memory moduleData = new bytes[](2);
        
        mintableModule = new MintableERC20(address(0x0));
        polygonAgglayer = new PolygonAgglayerCrossChain();
        console.log("mintableModule deployed to:", address(mintableModule));
        console.log("polygonAgglayer deployed to:", address(polygonAgglayer));

        bytes memory mintableEncodedInstallParams = abi.encode(deployerAddress);
        bytes memory polygonAgglayerEncodedInstallParams = abi.encode(address(polygonAgglayer));

        modules[0] = address(mintableModule);
        modules[1] = address(polygonAgglayer);

        moduleData[0] = mintableEncodedInstallParams;
        moduleData[1] = polygonAgglayerEncodedInstallParams;

        core = new ERC20Core("test", "TEST", "", deployerAddress, modules, moduleData);
        console.log("core deployed to:", address(core));

        core.grantRoles(deployerAddress, Role._MINTER_ROLE);
        core.mint(deployerAddress, 100, "");
        console.log("Minted test tokens to deployer");

        core.approve(agglayerBridgeExtension, 100);
        console.log("Approved agglayer bridge extension");

        bytes memory extraArgs = abi.encode(deployerAddress, true, address(core), 100);
        bytes memory payload = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,uint256)")),
            deployerAddress,
            1
        );
        
        PolygonAgglayerCrossChain(address(core)).sendCrossChainTransaction(
            destinationChain,
            testNFTAddress,
            payload,
            extraArgs
        );

        vm.stopBroadcast();
    }
}
