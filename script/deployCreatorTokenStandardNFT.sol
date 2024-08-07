// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {Role} from "src/Role.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";
import {MintableERC721} from "src/module/token/minting/MintableERC721.sol";
import {RoyaltyERC721} from "src/module/token/royalty/RoyaltyERC721.sol";

contract DeployCreatorTokenStandardNFT is Script {
    ERC721Core public core;
    RoyaltyERC721 public royalty;
    MintableERC721 public mintable;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.envAddress("DEPLOYER_WALLET_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        royalty = new RoyaltyERC721();
        mintable = new MintableERC721();
        console.log("royalty and mintable deployed");
        console.logAddress(address(royalty));
        console.logAddress(address(mintable));

        bytes memory royaltyInstallData = royalty.encodeBytesOnInstall(
            deployerAddress,
            100,
            address(0)
        );
        bytes memory mintableInstallData = mintable.encodeBytesOnInstall(
            deployerAddress
        );

        address[] memory modules = new address[](2);
        bytes[] memory moduleInstallData = new bytes[](2);

        modules[0] = address(royalty);
        moduleInstallData[0] = royaltyInstallData;
        modules[1] = address(mintable);
        moduleInstallData[1] = mintableInstallData;

        core = new ERC721Core(
            "creator token standard",
            "CTS",
            "",
            deployerAddress,
            modules,
            moduleInstallData
        );

        console.log("core deployed");
        console.logAddress(address(core));

        core.grantRoles(deployerAddress, Role._MINTER_ROLE);
        console.log("core granted minter role to deployer wallet");
        console.logAddress(deployerAddress);

        MintableERC721.MintRequestERC721 memory mintRequest = MintableERC721
            .MintRequestERC721({
                startTimestamp: 0,
                endTimestamp: 0,
                recipient: address(0),
                quantity: 0,
                currency: address(0),
                pricePerUnit: 0,
                baseURI: "",
                uid: ""
            });
        MintableERC721.MintParamsERC721 memory params = MintableERC721
            .MintParamsERC721(mintRequest, bytes(""), "");
        core.mint(deployerAddress, 1, abi.encode(params));
        console.log("minted");

        vm.stopBroadcast();
    }
}
