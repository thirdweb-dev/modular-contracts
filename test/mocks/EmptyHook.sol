// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/hook/ERC20Hook.sol";
import "src/hook/ERC721Hook.sol";
import "src/hook/ERC1155Hook.sol";

contract EmptyHookERC20 is ERC20Hook {
    function initialize() public initializer {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
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

contract EmptyHookERC721 is ERC721Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize() public initializer {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
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

contract EmptyHookERC1155 is ERC1155Hook {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize() public initializer {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG();
    }

    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        return new bytes4[](0);
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
