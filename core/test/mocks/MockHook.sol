// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHook} from "src/interface/hook/IHook.sol";
import {HookFlagsDirectory} from "src/hook/HookFlagsDirectory.sol";

import {BeforeMintHookERC20} from "src/hook/BeforeMintHookERC20.sol";
import {BeforeTransferHookERC20} from "src/hook/BeforeTransferHookERC20.sol";
import {BeforeBurnHookERC20} from "src/hook/BeforeBurnHookERC20.sol";
import {BeforeApproveHookERC20} from "src/hook/BeforeApproveHookERC20.sol";

import {BeforeMintHookERC721} from "src/hook/BeforeMintHookERC721.sol";
import {BeforeMintHookERC1155} from "src/hook/BeforeMintHookERC1155.sol";
import {OnTokenURIHook} from "src/hook/OnTokenURIHook.sol";

import "@solady/utils/Initializable.sol";
import "@solady/utils/UUPSUpgradeable.sol";

contract MockHookWithPermissionedFallback is IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = 0;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](1);
        hookInfo.hookFallbackFunctions[0] =
            HookFallbackFunction(this.permissionedFunction.selector, CallType.CALL, true);
    }

    function permissionedFunction() external pure virtual returns (uint256) {
        return 1;
    }
}

contract MockHookERC20 is BeforeMintHookERC20, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC20_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract BuggyMockHookERC20 is BeforeMintHookERC20, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC20_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract MockHookERC721 is BeforeMintHookERC721, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC721_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract BuggyMockHookERC721 is BeforeMintHookERC721, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC721_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract MockHookERC1155 is BeforeMintHookERC1155, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC1155_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract BuggyMockHookERC1155 is BeforeMintHookERC1155, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC1155_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
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

contract MockOnTokenURIHook is OnTokenURIHook, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = ON_TOKEN_URI_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return "mockURI/0";
    }
}

contract MockOneHookImpl is BeforeMintHookERC20, IHook, Initializable, UUPSUpgradeable, HookFlagsDirectory {
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC20_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockFourHookImpl is
    IHook,
    BeforeMintHookERC20,
    BeforeTransferHookERC20,
    BeforeBurnHookERC20,
    BeforeApproveHookERC20,
    Initializable,
    UUPSUpgradeable,
    HookFlagsDirectory
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

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags =
            BEFORE_MINT_ERC20_FLAG | BEFORE_TRANSFER_ERC20_FLAG | BEFORE_APPROVE_ERC20_FLAG | BEFORE_BURN_ERC20_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}
