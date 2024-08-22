pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ModularModule} from "src/ModularModule.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {CreatorTokenTransferValidator} from "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidator.sol";
import {Role} from "src/Role.sol";
import {IModularCore} from "src/interface/IModularCore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {MintableERC721} from "src/module/token/minting/MintableERC721.sol";
import {RoyaltyERC721} from "src/module/token/royalty/RoyaltyERC721.sol";

contract RoyaltyCreatorStandard is Script {
    ERC721Core public core;
    RoyaltyERC721 public royaltyModule;
    MintableERC721 public mintableModule;
    CreatorTokenTransferValidator public transferValidator;

    address SEAPORT = 0x00000000006c3852cbEf3e08E8dF289169EdE581;
    address SEAPORT_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function run() external {
        uint256 ownerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.envAddress("DEPLOYER_WALLET_ADDRESS");
        vm.startBroadcast(ownerPrivateKey);

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        royaltyModule = new RoyaltyERC721();
        mintableModule = new MintableERC721();
        console.log("modular core deployed");
        console.logAddress(address(core));

        // install module
        bytes memory royaltyInitializeData = royaltyModule.encodeBytesOnInstall(
            owner,
            100,
            0x721C0078c2328597Ca70F5451ffF5A7B38D4E947
        );
        bytes memory mintableInitializeData = mintableModule
            .encodeBytesOnInstall(owner);

        // install module
        core.installModule(address(royaltyModule), royaltyInitializeData);
        core.installModule(address(mintableModule), mintableInitializeData);
        console.log("modules installed");

        core.grantRoles(owner, Role._MINTER_ROLE);
        console.log("owner granted minter role");

        MintableERC721(address(core)).setSaleConfig(owner);
        MintableERC721.MintParamsERC721 memory params;
        core.mint(owner, 100, abi.encode(params));
        console.log("minted 100 tokens to owner");

        transferValidator = CreatorTokenTransferValidator(
            0x721C0078c2328597Ca70F5451ffF5A7B38D4E947
        );

        transferValidator.setTransferSecurityLevelOfCollection(
            address(core),
            3,
            false,
            false,
            false
        );
        console.log("transfer security level set");

        uint120 listId = transferValidator.createList("testListRoyalty");
        address[] memory list = new address[](2);
        list[0] = address(SEAPORT);
        list[1] = address(SEAPORT_CONDUIT);
        transferValidator.addAccountsToWhitelist(listId, list);
        transferValidator.applyListToCollection(address(core), listId);
        console.log(
            "Seaport and Seaport Conduit added to whitelist and applied to collection"
        );

        vm.stopBroadcast();
    }
}
