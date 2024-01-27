// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/erc721/hooks/ERC721Hook.sol";
import "src/erc20/hooks/ERC20Hook.sol";

contract MockOneHookImpl is ERC721Hook {
    constructor() {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG;
    }
}

contract MockFourHookImpl is ERC721Hook {
    constructor() {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | BEFORE_TRANSFER_FLAG | BEFORE_BURN_FLAG | BEFORE_APPROVE_FLAG;
    }
}

contract MockOneHookImpl20 is ERC20Hook {
    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG;
    }
}

contract MockFourHookImpl20 is ERC20Hook {
    constructor() {}

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | BEFORE_TRANSFER_FLAG | BEFORE_BURN_FLAG | BEFORE_APPROVE_FLAG;
    }
}
