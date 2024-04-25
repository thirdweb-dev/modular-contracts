// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BeforeMintHookERC20} from "src/hook/BeforeMintHookERC20.sol";
import {BeforeMintHookERC721} from "src/hook/BeforeMintHookERC721.sol";

import {BeforeTransferHookERC20} from "src/hook/BeforeTransferHookERC20.sol";
import {BeforeTransferHookERC721} from "src/hook/BeforeTransferHookERC721.sol";

import {BeforeBurnHookERC20} from "src/hook/BeforeBurnHookERC20.sol";
import {BeforeBurnHookERC721} from "src/hook/BeforeBurnHookERC721.sol";

import {BeforeApproveHookERC20} from "src/hook/BeforeApproveHookERC20.sol";
import {BeforeApproveHookERC721} from "src/hook/BeforeApproveHookERC721.sol";

import {OnTokenURIHook} from "src/hook/OnTokenURIHook.sol";

import {IExtensionContract} from "src/interface/IExtensionContract.sol";

import "@solady/utils/Initializable.sol";
import "@solady/utils/UUPSUpgradeable.sol";

contract MockExtensionERC20 is BeforeMintHookERC20, IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.callbackFunctions[0] = this.beforeMintERC20.selector;
    }

    function beforeMintERC20(address _to, uint256 _amount, bytes memory _data)
        external
        payable
        override
        returns (bytes memory)
    {
        return abi.encode(_amount);
    }
}

contract MockExtensionWithOnTokenURICallback is OnTokenURIHook, IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory) {
        bytes4[] memory callbackFunctions = new bytes4[](1);
        callbackFunctions[0] = this.onTokenURI.selector;
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](0);
        return ExtensionConfig(callbackFunctions, extensionABI);
    }

    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return "mockURI/0";
    }
}

contract MockExtensionWithPermissionedFallback is IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory) {
        bytes4[] memory callbackFunctions = new bytes4[](0);
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](1);
        extensionABI[0] = ExtensionFunction(this.permissionedFunction.selector, CallType.CALL, true);
        return ExtensionConfig(callbackFunctions, extensionABI);
    }

    function permissionedFunction() external pure virtual returns (uint256) {
        return 1;
    }
}

contract MockExtensionWithOneCallbackERC20 is
    BeforeMintHookERC20,
    IExtensionContract,
    Initializable,
    UUPSUpgradeable
{
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory) {
        bytes4[] memory callbackFunctions = new bytes4[](1);
        callbackFunctions[0] = this.beforeMintERC20.selector;
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](0);
        return ExtensionConfig(callbackFunctions, extensionABI);
    }
}

contract MockExtensionWithFourCallbacksERC20 is
    IExtensionContract,
    BeforeMintHookERC20,
    BeforeTransferHookERC20,
    BeforeBurnHookERC20,
    BeforeApproveHookERC20,
    Initializable,
    UUPSUpgradeable
{
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory) {
        bytes4[] memory callbackFunctions = new bytes4[](4);
        callbackFunctions[0] = this.beforeMintERC20.selector;
        callbackFunctions[1] = this.beforeTransferERC20.selector;
        callbackFunctions[2] = this.beforeBurnERC20.selector;
        callbackFunctions[3] = this.beforeApproveERC20.selector;
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](0);
        return ExtensionConfig(callbackFunctions, extensionABI);
    }
}

contract BuggyMockExtensionERC20 is BeforeMintHookERC20, IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.callbackFunctions[0] = this.beforeMintERC20.selector;
    }

    error BuggyMinting();

    function beforeMintERC20(address _to, uint256 _amount, bytes memory _data)
        external
        payable
        override
        returns (bytes memory)
    {
        address token = msg.sender;
        revert BuggyMinting();
    }
}

contract MockExtensionERC721 is BeforeMintHookERC721, IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    mapping(address => uint256) nextTokenIdToMint;

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.callbackFunctions[0] = this.beforeMintERC721.selector;
    }

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        override
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = nextTokenIdToMint[token];
        nextTokenIdToMint[token] += _quantity;

        uint256 quantityToMint = _quantity;

        return abi.encode(tokenIdToMint, quantityToMint);
    }
}

contract BuggyMockExtensionERC721 is BeforeMintHookERC721, IExtensionContract, Initializable, UUPSUpgradeable {
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    mapping(address => uint256) nextTokenIdToMint;

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.callbackFunctions[0] = this.beforeMintERC721.selector;
    }

    error BuggyMinting();

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        override
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = nextTokenIdToMint[token];
        nextTokenIdToMint[token] += _quantity;

        uint256 quantityToMint = _quantity;

        revert BuggyMinting();
    }
}

contract MockExtensionWithOneCallbackERC721 is
    BeforeMintHookERC721,
    IExtensionContract,
    Initializable,
    UUPSUpgradeable
{
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.callbackFunctions[0] = this.beforeMintERC721.selector;
    }
}

contract MockExtensionWithFourCallbacksERC721 is
    IExtensionContract,
    BeforeMintHookERC721,
    BeforeTransferHookERC721,
    BeforeBurnHookERC721,
    BeforeApproveHookERC721,
    Initializable,
    UUPSUpgradeable
{
    address public upgradeAdmin;

    function initialize(address _upgradeAdmin) public initializer {
        upgradeAdmin = _upgradeAdmin;
    }

    error UnauthorizedUpgrade();

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != upgradeAdmin) {
            revert UnauthorizedUpgrade();
        }
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](4);
        config.callbackFunctions[0] = this.beforeMintERC721.selector;
        config.callbackFunctions[1] = this.beforeTransferERC721.selector;
        config.callbackFunctions[2] = this.beforeBurnERC721.selector;
        config.callbackFunctions[3] = this.beforeApproveERC721.selector;
    }
}
