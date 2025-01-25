// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Role} from "src/Role.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";
import {MintableERC1155} from "src/module/token/minting/MintableERC1155.sol";
import {BatchMetadataERC1155} from "src/module/token/metadata/BatchMetadataERC1155.sol";
import {BurnToRedeemERC1155} from "src/module/token/burnable/BurnToRedeemERC1155.sol";

contract BurnToRedeemScript is Script {

    ERC1155Core public core;
    BurnToRedeemERC1155 public burnToRedeemModule;
    BatchMetadataERC1155 public batchMetadataModule;
    MintableERC1155 public mintableModule;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        
        core = new ERC1155Core("test", "TEST", "", deployerAddress, new address[](0), new bytes[](0));
        mintableModule = new MintableERC1155(address(0x0));
        batchMetadataModule = new BatchMetadataERC1155();
        burnToRedeemModule = new BurnToRedeemERC1155();
        console.log("core deployed at: ", address(core));
        console.log("burn to redeem module deployed at: ", address(burnToRedeemModule));

        core.installModule(address(burnToRedeemModule), "");
        console.log("burn to redeem module installed");

        bytes memory encodedInstallParams = abi.encode(deployerAddress);
        core.installModule(address(mintableModule), encodedInstallParams);
        console.log("mintable module installed");

        core.installModule(address(batchMetadataModule), "");
        console.log("batch metadata module installed");

        core.grantRoles(deployerAddress, Role._MINTER_ROLE);

        core.mint(deployerAddress, 0, 10, "", "");
        console.log("minted 10 tokens to deployer");

        BurnToRedeemERC1155(address(core)).burnToRedeem(deployerAddress, 0, 1);
        console.log("burned 1 token to redeem");

        vm.stopBroadcast();
    }
}
