// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";
import {Role} from "src/Role.sol";

// Target contract

import {Module} from "src/Module.sol";
import {ERC1155Core} from "src/core/token/ERC1155Core.sol";

import {ICore} from "src/interface/ICore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {ImmutableAllowlistERC1155} from "src/module/token/immutable/ImmutableAllowlistERC1155.sol";

import {OperatorAllowlistEnforced} from "dependecies/immutable/allowlist/OperatorAllowlistEnforced.sol";
import {OperatorAllowlistEnforcementErrors} from "dependecies/immutable/errors/Errors.sol";
import {OperatorAllowlist} from "dependecies/immutable/test/allowlist/OperatorAllowlist.sol";

contract Core is ERC1155Core {

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory modules,
        bytes[] memory moduleInstallData
    ) ERC1155Core(name, symbol, contractURI, owner, modules, moduleInstallData) {}

    // disable mint, approve and tokenId callbacks for these tests
    function _beforeMint(address to, uint256 tokenId, uint256 value, bytes memory data) internal override {}

    function _updateTokenId(uint256 tokenId) internal override returns (uint256) {
        return tokenId;
    }

}

contract DummyContract {

    ERC1155Core public immutable erc1155Core;

    constructor(address payable _erc1155Core) {
        erc1155Core = ERC1155Core(_erc1155Core);
    }

    // Implement the IERC1155Receiver functions to accept ERC1155 tokens

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // Required to declare support for the ERC1155Receiver interface
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x4e2312e0;
    }

    // Set approval for the operator to manage tokens
    function setApprovalForAll(address _operator) external {
        erc1155Core.setApprovalForAll(_operator, true);
    }

    // Transfer a single token
    function transfer(address _to, uint256 _tokenId) external {
        erc1155Core.safeTransferFrom(address(this), _to, _tokenId, 1, "");
    }

    // Batch transfer multiple tokens
    function batchTransfer(address _to, uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        erc1155Core.safeBatchTransferFrom(address(this), _to, tokenIds, amounts, "");
    }

}

contract ImmutableAllowlistERC1155Test is Test {

    Core public core;

    ImmutableAllowlistERC1155 public immutableAllowlistModule;
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
        immutableAllowlistModule = new ImmutableAllowlistERC1155();

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
        core.mint(actorOne, 0, 1, string(""), ""); // tokenId 0
        core.mint(actorTwo, 1, 1, string(""), ""); // tokenId 1
        core.mint(actorThree, 3, 1, string(""), ""); // tokenId 2

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
        ImmutableAllowlistERC1155(address(core)).setOperatorAllowlistRegistry(address(operatorAllowlist2));

        assertEq(ImmutableAllowlistERC1155(address(core)).operatorAllowlist(), address(operatorAllowlist2));
    }

    function test_revert_setOperatorAllowlistRegistry() public {
        vm.prank(owner);
        // should revert since the allowlist does not implement the IOperatorAllowlist interface
        // and that it doesn't implement supportsInterface
        vm.expectRevert();
        ImmutableAllowlistERC1155(address(core)).setOperatorAllowlistRegistry(address(0x123));
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `beforeApproveForAll`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeApproveForAllERC1155() public {
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
        core.mint(actorThree, 3, 1, string(""), ""); // tokenId 3
        core.safeTransferFrom(actorThree, address(dummyContract1), 3, 1, "");
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        dummyContract1.setApprovalForAll(address(dummyContract2));
    }

    function test_revert_beforeApproveForAllERC1155() public {
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.ApproveTargetNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.setApprovalForAll(address(dummyContract1), true);
    }

    /*///////////////////////////////////////////////////////////////
                   Unit tests: `beforeTransferERC1155`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeTransferERC1155() public {
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
        core.safeTransferFrom(actorOne, actorTwo, 0, 1, "");

        // passes when msg.sender is an EOA and targetApproval is a contract and is allowlisted
        core.mint(actorThree, 3, 1, string(""), ""); // tokenId 3
        vm.startPrank(actorThree);
        core.safeTransferFrom(actorThree, address(dummyContract1), 3, 1, "");
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        dummyContract1.transfer(address(dummyContract2), 3);
    }

    function test_revert_beforeTransferERC1155() public {
        // fails when msg.sender is not allowlisted
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(OperatorAllowlistEnforcementErrors.CallerNotInAllowlist.selector, actorOne)
        );
        core.safeTransferFrom(actorOne, actorTwo, 0, 1, "");

        // fails when target is not allowlisted
        allowlist(actorOne);
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.TransferToNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.safeTransferFrom(actorOne, address(dummyContract1), 0, 1, "");
    }

    /*///////////////////////////////////////////////////////////////
                   Unit tests: `beforeTransferERC1155`
    //////////////////////////////////////////////////////////////*/

    function test_state_beforeBatchTransferERC1155() public {
        // set allowlist
        address[] memory allowlist = new address[](5);
        allowlist[0] = address(dummyContract1);
        allowlist[1] = address(dummyContract2);
        allowlist[2] = address(actorOne);
        allowlist[3] = address(actorTwo);
        allowlist[4] = address(actorThree);
        vm.prank(owner);
        operatorAllowlist.addAddressToAllowlist(allowlist);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.prank(actorOne);
        core.safeBatchTransferFrom(actorOne, actorTwo, tokenIds, amounts, "");

        // passes when msg.sender is an EOA and targetApproval is a contract and is allowlisted
        core.mint(actorThree, 3, 1, string(""), ""); // tokenId 3
        vm.startPrank(actorThree);
        core.safeTransferFrom(actorThree, address(dummyContract1), 3, 1, "");
        vm.stopPrank();

        // passes when msg.sender is a contract and is allowlisted
        // and when targetApproval is a contract and is allowlisted
        uint256[] memory _tokenIds = new uint256[](1);
        tokenIds[0] = 3;
        uint256[] memory _amounts = new uint256[](1);
        amounts[0] = 1;
        dummyContract1.batchTransfer(address(dummyContract2), _tokenIds, _amounts);
    }

    function test_revert_beforeBatchTransferERC1155() public {
        // fails when msg.sender is not allowlisted
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(OperatorAllowlistEnforcementErrors.CallerNotInAllowlist.selector, actorOne)
        );
        core.safeBatchTransferFrom(actorOne, actorTwo, tokenIds, amounts, "");

        // fails when target is not allowlisted
        uint256[] memory _tokenIds = new uint256[](1);
        tokenIds[0] = 3;
        uint256[] memory _amounts = new uint256[](1);
        amounts[0] = 1;
        allowlist(actorOne);
        vm.prank(actorOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                OperatorAllowlistEnforcementErrors.TransferToNotInAllowlist.selector, address(dummyContract1)
            )
        );
        core.safeBatchTransferFrom(actorOne, address(dummyContract1), _tokenIds, _amounts, "");
    }

}
