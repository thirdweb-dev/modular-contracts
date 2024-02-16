// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/extension/ERC20Extension.sol";
import "src/extension/ERC721Extension.sol";
import "src/extension/ERC1155Extension.sol";

contract EmptyExtensionERC20 is ERC20Extension {
    function initialize() public initializer {}

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG();
    }

    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        return _quantity;
    }
}

contract EmptyExtensionERC721 is ERC721Extension {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize() public initializer {}

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG();
    }

    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;

        tokenIdToMint = nextTokenIdToMint[token];
        nextTokenIdToMint[token] += _quantity;

        quantityToMint = _quantity;
    }
}

contract EmptyExtensionERC1155 is ERC1155Extension {
    mapping(address => uint256) nextTokenIdToMint;

    function initialize() public initializer {}

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG();
    }

    function beforeMint(address _to, uint256 _id, uint256 _value, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;

        tokenIdToMint = _id;
        quantityToMint = _value;
    }
}
