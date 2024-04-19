// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BeforeMintHookERC20} from "src/hook/BeforeMintHookERC20.sol";
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

    function getExtensionConfig() external pure override returns (ExtensionConfig memory) {
        bytes4[] memory callbackFunctions = new bytes4[](1);
        callbackFunctions[0] = this.beforeMintERC20.selector;
        ExtensionFunction[] memory extensionABI = new ExtensionFunction[](0);
        return ExtensionConfig(callbackFunctions, extensionABI);
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
