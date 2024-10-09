// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {Test} from "forge-std/Test.sol";

// Target contract

import {Core} from "src/Core.sol";
import {Module} from "src/Module.sol";

import {Role} from "src/Role.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";

import {BatchMetadataERC1155} from "src/module/token/metadata/BatchMetadataERC1155.sol";
import {BatchMetadataERC721} from "src/module/token/metadata/BatchMetadataERC721.sol";
import {MintableERC1155} from "src/module/token/minting/MintableERC1155.sol";
import {SequentialTokenIdERC1155} from "src/module/token/tokenId/SequentialTokenIdERC1155.sol";

contract MockCurrency is ERC20 {

    function mintTo(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return "MockCurrency";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return "MOCK";
    }

}

contract MintableERC1155Test is Test {

    ERC1155Core public core;

    MintableERC1155 public mintableModule;
    BatchMetadataERC1155 public batchMetadataModule;
    SequentialTokenIdERC1155 public sequentialTokenIdModule;

    uint256 ownerPrivateKey = 1;
    address public owner;

    address tokenRecipient = address(0x123);

    MintableERC1155.MintSignatureParamsERC1155 public mintRequest;

    // Constants
    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);

        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC1155Core("test", "TEST", "", owner, modules, moduleData);
        mintableModule = new MintableERC1155();
        batchMetadataModule = new BatchMetadataERC1155();
        sequentialTokenIdModule = new SequentialTokenIdERC1155();

        // install module
        bytes memory encodedInstallParams = abi.encode(owner);
        vm.prank(owner);
        core.installModule(address(mintableModule), encodedInstallParams);

        vm.prank(owner);
        core.installModule(address(batchMetadataModule), "");

        bytes memory encodedTokenIdInstallParams = sequentialTokenIdModule.encodeBytesOnInstall(0);
        vm.prank(owner);
        core.installModule(address(sequentialTokenIdModule), encodedTokenIdInstallParams);

        // Give permissioned actor minter role
        vm.prank(owner);
        core.grantRoles(owner, Role._MINTER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: onInstall
    //////////////////////////////////////////////////////////////*/

    function test_onInstall() public {
        vm.startPrank(owner);
        core.uninstallModule(address(sequentialTokenIdModule), "");
        core.installModule(address(sequentialTokenIdModule), sequentialTokenIdModule.encodeBytesOnInstall(5));
        vm.stopPrank();

        assertEq(SequentialTokenIdERC1155(address(core)).getNextTokenId(), 5);
    }

    /*//////////////////////////////////////////////////////////////
                        Tests: beforeMintERC1155
    //////////////////////////////////////////////////////////////*/

    function test_state_updateTokenId() public {
        assertEq(SequentialTokenIdERC1155(address(core)).getNextTokenId(), 0);

        // increments the tokenId
        vm.prank(owner);
        core.mint(owner, type(uint256).max, 10, "", "");

        assertEq(SequentialTokenIdERC1155(address(core)).getNextTokenId(), 1);

        // does not increment the tokenId
        vm.prank(owner);
        core.mint(owner, 1, 10, "", "");

        assertEq(SequentialTokenIdERC1155(address(core)).getNextTokenId(), 1);
    }

    function test_revert_updateTokenId() public {
        vm.expectRevert(SequentialTokenIdERC1155.SequentialTokenIdInvalidTokenId.selector);
        vm.prank(owner);
        core.mint(owner, 2, 1, "", "");
    }

}
