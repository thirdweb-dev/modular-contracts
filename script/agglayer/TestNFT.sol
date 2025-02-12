// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC721A} from "@erc721a/ERC721A.sol";

contract TestNFT is ERC721A {

    constructor(string memory _name, string memory _symbol) ERC721A(_name, _symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}
