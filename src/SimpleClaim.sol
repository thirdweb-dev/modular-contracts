// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.

import { ERC721Core } from "./ERC721Core.sol"; 

contract SimpleClaim {

    address public erc721;

    uint256 public price;
    uint256 public availableSupply;

    mapping(address => bool) public hasClaimed;

    constructor(address _erc721, uint256 _price, uint256 _availableSupply) {
        erc721 = _erc721;
        price = _price;
        availableSupply = _availableSupply;
    }

    function claim() public payable {
        address to = msg.sender;

        require(msg.value == price, "Insufficient funds");
        require(availableSupply > 0, "No more available supply");
        require(!hasClaimed[to], "Already claimed");

        hasClaimed[to] = true;
        availableSupply -= 1;

        ERC721Core erc721Core = ERC721Core(erc721);
        erc721Core.mint(to);
    }
}