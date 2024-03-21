// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/hook/ERC20Hook.sol";
import "src/hook/ERC721Hook.sol";
import "src/hook/ERC1155Hook.sol";

contract EmptyHookERC20 is ERC20Hook {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC20Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        return _mintRequest.quantity;
    }
}

contract BuggyEmptyHookERC20 is ERC20Hook {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC20Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        // Bug: Minting zero tokens in all cases!
        return 0;
    }
}

contract EmptyHookERC721 is ERC721Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    error EmptyHookNotToken();

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        if (_mintRequest.token != msg.sender) {
            revert EmptyHookNotToken();
        }

        tokenIdToMint = nextTokenIdToMint[token];
        nextTokenIdToMint[token] += _mintRequest.quantity;

        quantityToMint = _mintRequest.quantity;
    }
}

contract BuggyEmptyHookERC721 is ERC721Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    error EmptyHookNotToken();

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        if (_mintRequest.token != msg.sender) {
            revert EmptyHookNotToken();
        }

        tokenIdToMint = nextTokenIdToMint[token];
        nextTokenIdToMint[token] += _mintRequest.quantity;

        // Bug: Minting zero tokens in all cases!
        quantityToMint = 0;
    }
}

contract EmptyHookERC1155 is ERC1155Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize(address _upgradeAdmin) public initializer {
        __ERC1155Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;

        tokenIdToMint = _mintRequest.tokenId;
        quantityToMint = _mintRequest.quantity;
    }
}

contract BuggyEmptyHookERC1155 is ERC1155Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize(address _upgradeAdmin) public initializer {
        __ERC1155Hook_init(_upgradeAdmin);
    }

    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = BEFORE_MINT_FLAG();
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](0);
    }

    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;

        tokenIdToMint = _mintRequest.tokenId;

        // Bug: Minting zero tokens in all cases!
        quantityToMint = 0;
    }
}
