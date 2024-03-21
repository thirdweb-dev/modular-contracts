// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHook} from "src/interface/hook/IHook.sol";
import {BeforeMintHookERC20} from "src/hook/BeforeMintHookERC20.sol";
import {BeforeMintHookERC721} from "src/hook/BeforeMintHookERC721.sol";
import {BeforeMintHookERC1155} from "src/hook/BeforeMintHookERC1155.sol";
import {OnTokenURIHook} from "src/hook/OnTokenURIHook.sol";

contract MockHookWithPermissionedFallback is IHook {
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

contract MockHookERC20 is BeforeMintHookERC20, IHook {
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

contract BuggyMockHookERC20 is BeforeMintHookERC20, IHook {
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
        address token = msg.sender;
        // Bug: Minting zero tokens in all cases!
        return abi.encode(0);
    }
}

contract MockHookERC721 is BeforeMintHookERC721, IHook {
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

contract BuggyMockHookERC721 is BeforeMintHookERC721, IHook {
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

        return abi.encode(tokenIdToMint, 0);
    }
}

contract MockHookERC1155 is BeforeMintHookERC1155, IHook {
    mapping(address => uint256) nextTokenIdToMint;

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC1155_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = _id;
        uint256 quantityToMint = _quantity;

        return abi.encode(tokenIdToMint, quantityToMint);
    }
}

contract BuggyMockHookERC1155 is BeforeMintHookERC1155, IHook {
    mapping(address => uint256) nextTokenIdToMint;

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC1155_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        address token = msg.sender;

        uint256 tokenIdToMint = _id;
        uint256 quantityToMint = _quantity;

        return abi.encode(tokenIdToMint, 0);
    }
}

contract MockOnTokenURIHook is OnTokenURIHook, IHook {
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = ON_TOKEN_URI_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return "mockURI/0";
    }
}

contract MockOneHookImpl is BeforeMintHookERC20, IHook {
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_ERC20_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}

contract MockFourHookImpl is BeforeMintHookERC20, BeforeMintHookERC721, BeforeMintHookERC1155, MockOnTokenURIHook {
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags =
            BEFORE_MINT_ERC20_FLAG | BEFORE_MINT_ERC20_FLAG | BEFORE_MINT_ERC1155_FLAG | ON_TOKEN_URI_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }
}
