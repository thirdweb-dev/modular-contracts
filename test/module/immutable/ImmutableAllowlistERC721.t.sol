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

contract DummyContract {

    ERC721Core public immutable erc721Core;

    constructor(address payable _erc721Core) {
        erc721Core = ERC721Core(_erc721Core);
    }

    function approve(address _to, uint256 _tokenId) external {
        erc721Core.approve(_to, _tokenId);
    }

    function setApprovalForAll(address _operator) external {
        erc721Core.setApprovalForAll(_operator, true);
    }

    function transfer(address _to, uint256 _tokenId) external {
        erc721Core.transferFrom(address(this), _to, _tokenId);
    }

}

contract ImmutableAllowlistERC721Test is Test {

    Core public core;

    ImmutableAllowlistERC721 public immutableAllowlistModule;
    OperatorAllowlist public operatorAllowlist;
    DummyContract public dummyContract1;
    DummyContract public dummyContract2;

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

        vm.prank(owner);
        operatorAllowlist = new OperatorAllowlist(owner);

        // install module
        vm.startPrank(owner);
        bytes memory encodedOperatorAllowlist =
            immutableAllowlistModule.encodeBytesOnInstall(address(operatorAllowlist));
        core.installModule(address(immutableAllowlistModule), encodedOperatorAllowlist);
        vm.stopPrank();

        // set registrar role for owner
        vm.prank(owner);
        operatorAllowlist.grantRegistrarRole(owner);

        // deploy dummy contract
        dummyContract1 = new DummyContract(payable(address(core)));
        dummyContract2 = new DummyContract(payable(address(core)));

        // mint tokens
        core.mint(actorOne, 1, string(""), ""); // tokenId 0
        core.mint(actorTwo, 1, string(""), ""); // tokenId 1
        core.mint(actorThree, 1, string(""), ""); // tokenId 2

        vm.prank(owner);
        core.grantRoles(owner, Role._MANAGER_ROLE);
    }

    function allowlist(address _target) internal {
        address[] memory allowlist = new address[](1);
        allowlist[0] = _target;
        vm.prank(owner);
        operatorAllowlist.addAddressToAllowlist(allowlist);
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
                        Unit tests: `beforeApproveERC721`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeApproveERC721() public {
        // passes when msg.sender is an EOA and targetApproval is an EOA
        vm.prank(actorOne);
        core.approve(actorTwo, 0);

        // set allowlist for dummy contract
        address[] memory allowlist = new address[](3);
        allowlist[0] = address(dummyContract1);
        allowlist[1] = address(dummyContract2);
        allowlist[2] = address(actorThree);
        vm.prank(owner);
        operatorAllowlist.addAddressToAllowlist(allowlist);

        vm.startPrank(actorThree);
        core.mint(actorThree, 2, string(""), ""); // tokenId 3
        core.transferFrom(actorThree, address(dummyContract1), 3);
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        dummyContract1.approve(address(dummyContract2), 3);
    }

    function test_revert_beforeApproveERC721() public {
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.ApproveTargetNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.approve(address(dummyContract1), 0);
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `beforeApproveForAll`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeApproveForAllERC721() public {
        // passes when msg.sender is an EOA and targetApproval is an EOA
        vm.prank(actorOne);
        core.setApprovalForAll(actorTwo, true);

        // set allowlist for dummy contract
        address[] memory allowlist = new address[](3);
        allowlist[0] = address(dummyContract1);
        allowlist[1] = address(dummyContract2);
        allowlist[2] = address(actorThree);
        vm.prank(owner);
        operatorAllowlist.addAddressToAllowlist(allowlist);

        vm.startPrank(actorThree);
        core.mint(actorThree, 1, string(""), ""); // tokenId 3
        core.transferFrom(actorThree, address(dummyContract1), 3);
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        dummyContract1.setApprovalForAll(address(dummyContract2));
    }

    function test_revert_beforeApproveForAllERC721() public {
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.ApproveTargetNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.setApprovalForAll(address(dummyContract1), true);
    }

    /*///////////////////////////////////////////////////////////////
                   Unit tests: `beforeTransferERC721`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeTransferERC721() public {
        // set allowlist
        address[] memory allowlist = new address[](5);
        allowlist[0] = address(dummyContract1);
        allowlist[1] = address(dummyContract2);
        allowlist[2] = address(actorOne);
        allowlist[3] = address(actorTwo);
        allowlist[4] = address(actorThree);
        vm.prank(owner);
        operatorAllowlist.addAddressToAllowlist(allowlist);

        vm.prank(actorOne);
        core.transferFrom(actorOne, actorTwo, 0);

        // passes when msg.sender is an EOA and targetApproval is a contract and is allowlisted
        core.mint(actorThree, 1, string(""), ""); // tokenId 3
        vm.startPrank(actorThree);
        core.transferFrom(actorThree, address(dummyContract1), 3);
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        dummyContract1.transfer(address(dummyContract2), 3);
    }

    function test_revert_beforeTransferERC721() public {
        // fails when msg.sender is not allowlisted
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(OperatorAllowlistEnforcementErrors.CallerNotInAllowlist.selector, actorOne)
        );
        core.transferFrom(actorOne, actorTwo, 0);

        // fails when target is not allowlisted
        allowlist(actorOne);
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.TransferToNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.transferFrom(actorOne, address(dummyContract1), 0);
    }

}
