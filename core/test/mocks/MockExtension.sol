// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BeforeMintCallbackERC20} from "src/callback/BeforeMintCallbackERC20.sol";
import {BeforeMintCallbackERC721} from "src/callback/BeforeMintCallbackERC721.sol";
import {BeforeMintCallbackERC1155} from "src/callback/BeforeMintCallbackERC1155.sol";

import {BeforeTransferCallbackERC20} from "src/callback/BeforeTransferCallbackERC20.sol";
import {BeforeTransferCallbackERC721} from "src/callback/BeforeTransferCallbackERC721.sol";
import {BeforeTransferCallbackERC1155} from "src/callback/BeforeTransferCallbackERC1155.sol";

import {BeforeBurnCallbackERC20} from "src/callback/BeforeBurnCallbackERC20.sol";
import {BeforeBurnCallbackERC721} from "src/callback/BeforeBurnCallbackERC721.sol";
import {BeforeBurnCallbackERC1155} from "src/callback/BeforeBurnCallbackERC1155.sol";

import {BeforeApproveCallbackERC20} from "src/callback/BeforeApproveCallbackERC20.sol";
import {BeforeApproveCallbackERC721} from "src/callback/BeforeApproveCallbackERC721.sol";
import {BeforeApproveForAllCallback} from "src/callback/BeforeApproveForAllCallback.sol";

import {OnTokenURICallback} from "src/callback/OnTokenURICallback.sol";

import {IModularExtension} from "src/interface/IModularExtension.sol";

import "@solady/utils/Initializable.sol";
import "@solady/utils/UUPSUpgradeable.sol";

contract MockExtensionERC20 is BeforeMintCallbackERC20, IModularExtension, Initializable, UUPSUpgradeable {
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

contract MockExtensionWithOnTokenURICallback is
    OnTokenURICallback,
    IModularExtension,
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
        callbackFunctions[0] = this.onTokenURI.selector;
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](0);
        return ExtensionConfig(bytes4(0), false, new bytes4[](0), callbackFunctions, extensionABI);
    }

    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return "mockURI/0";
    }
}

contract MockExtensionWithPermissionedFallback is IModularExtension, Initializable, UUPSUpgradeable {
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
        return ExtensionConfig(bytes4(0), false, new bytes4[](0), callbackFunctions, extensionABI);
    }

    function permissionedFunction() external pure virtual returns (uint256) {
        return 1;
    }
}

contract MockExtensionWithOneCallbackERC20 is
    BeforeMintCallbackERC20,
    IModularExtension,
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
        return ExtensionConfig(bytes4(0), false, new bytes4[](0), callbackFunctions, extensionABI);
    }
}

contract MockExtensionWithFourCallbacksERC20 is
    IModularExtension,
    BeforeMintCallbackERC20,
    BeforeTransferCallbackERC20,
    BeforeBurnCallbackERC20,
    BeforeApproveCallbackERC20,
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
        return ExtensionConfig(bytes4(0), false, new bytes4[](0), callbackFunctions, extensionABI);
    }
}

contract BuggyMockExtensionERC20 is BeforeMintCallbackERC20, IModularExtension, Initializable, UUPSUpgradeable {
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

contract MockExtensionERC721 is BeforeMintCallbackERC721, IModularExtension, Initializable, UUPSUpgradeable {
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

contract BuggyMockExtensionERC721 is BeforeMintCallbackERC721, IModularExtension, Initializable, UUPSUpgradeable {
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
    BeforeMintCallbackERC721,
    IModularExtension,
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
    IModularExtension,
    BeforeMintCallbackERC721,
    BeforeTransferCallbackERC721,
    BeforeBurnCallbackERC721,
    BeforeApproveCallbackERC721,
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

contract MockExtensionERC1155 is BeforeMintCallbackERC1155, IModularExtension, Initializable, UUPSUpgradeable {
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
        config.callbackFunctions[0] = this.beforeMintERC1155.selector;
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = _id;
        uint256 quantityToMint = _quantity;

        return abi.encode(tokenIdToMint, quantityToMint);
    }
}

contract BuggyMockExtensionERC1155 is BeforeMintCallbackERC1155, IModularExtension, Initializable, UUPSUpgradeable {
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
        config.callbackFunctions[0] = this.beforeMintERC1155.selector;
    }

    error BuggyMinting();

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = _id;
        uint256 quantityToMint = _quantity;

        revert BuggyMinting();
    }
}

contract MockExtensionWithOneCallbackERC1155 is
    BeforeMintCallbackERC1155,
    IModularExtension,
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
        config.callbackFunctions[0] = this.beforeMintERC1155.selector;
    }
}

contract MockExtensionWithFourCallbacksERC1155 is
    IModularExtension,
    BeforeMintCallbackERC1155,
    BeforeTransferCallbackERC1155,
    BeforeBurnCallbackERC1155,
    BeforeApproveForAllCallback,
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
        config.callbackFunctions[0] = this.beforeMintERC1155.selector;
        config.callbackFunctions[1] = this.beforeTransferERC1155.selector;
        config.callbackFunctions[2] = this.beforeBurnERC1155.selector;
        config.callbackFunctions[3] = this.beforeApproveForAll.selector;
    }
}
