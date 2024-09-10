// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {Role} from "src/Role.sol";

// Target contract

import {Module} from "src/Module.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {ImmutableAllowlistERC721} from "src/module/token/immutable/ImmutableAllowlistERC721.sol";

import {OperatorAllowlistEnforced} from "dependecies/immutable/allowlist/OperatorAllowlistEnforced.sol";
import {OperatorAllowlistEnforcementErrors} from "dependecies/immutable/errors/Errors.sol";
import {OperatorAllowlist} from "dependecies/immutable/test/allowlist/OperatorAllowlist.sol";

contract Core is ERC721Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory modules,
        bytes[] memory moduleInstallData
    ) ERC721Core(name, symbol, contractURI, owner, modules, moduleInstallData) {}

    // disable mint and approve callbacks for these tests
    function _beforeMint(address to, uint256 startTokenId, uint256 quantity, bytes calldata data) internal override {}

}

contract TransferableERC721Test is Test {

    Core public core;

    ImmutableAllowlistERC721 public immutableAllowlistModule;
    OperatorAllowlist public operatorAllowlist;

    address public owner = address(0x1);
    address public actorOne = address(0x2);
    address public actorTwo = address(0x3);
    address public actorThree = address(0x4);

    event OperatorAllowlistRegistryUpdated(address oldRegistry, address newRegistry);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new Core("test", "TEST", "", owner, modules, moduleData);
        immutableAllowlistModule = new ImmutableAllowlistERC721();
        operatorAllowlist = new OperatorAllowlist(owner);

        // install module
        vm.startPrank(owner);
        bytes memory encodedOperatorAllowlist =
            immutableAllowlistModule.encodeBytesOnInstall(address(operatorAllowlist));
        core.installModule(address(immutableAllowlistModule), encodedOperatorAllowlist);
        vm.stopPrank();

        // mint tokens
        core.mint(actorOne, 1, string(""), ""); // tokenId 0
        core.mint(actorTwo, 1, string(""), ""); // tokenId 1
        core.mint(actorThree, 1, string(""), ""); // tokenId 2

        vm.prank(owner);
        core.grantRoles(owner, Role._MANAGER_ROLE);
    }

    /*///////////////////////////////////////////////////////////////
                 Unit tests: `setOperatorAllowlistRegistry`
    //////////////////////////////////////////////////////////////*/

    function test_state_setOperatorAllowlistRegistry() public {
        OperatorAllowlist operatorAllowlist2 = new OperatorAllowlist(owner);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit OperatorAllowlistRegistryUpdated(address(operatorAllowlist), address(operatorAllowlist2));
        ImmutableAllowlistERC721(address(core)).setOperatorAllowlistRegistry(address(operatorAllowlist2));

        assertEq(ImmutableAllowlistERC721(address(core)).operatorAllowlist(), address(operatorAllowlist2));
    }

    function test_revert_setOperatorAllowlistRegistry() public {
        vm.prank(owner);
        // should revert since the allowlist does not implement the IOperatorAllowlist interface
        // and that it doesn't implement supportsInterface
        vm.expectRevert();
        ImmutableAllowlistERC721(address(core)).setOperatorAllowlistRegistry(address(0x123));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `setTransferable`
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721.approve
    function beforeApproveERC721(address _from, address _to, uint256 _tokenId, bool _approve)
        external
        returns (bytes memory)
    {}

    /// @notice Callback function for ERC721.setApprovalForAll
    function beforeApproveForAll(address _from, address _to, bool _approved) external returns (bytes memory) {}

    /// @notice Callback function for ERC721.transferFrom/safeTransferFrom
    function beforeTransferERC721(address _from, address _to, uint256 _tokenId) external returns (bytes memory) {}

}
