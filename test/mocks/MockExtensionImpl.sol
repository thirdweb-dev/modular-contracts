// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/extension/ERC721Extension.sol";
import "src/extension/ERC20Extension.sol";

contract MockOneExtensionImpl is ERC721Extension {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Extension_init(_upgradeAdmin);
    }

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_TRANSFER_FLAG();
    }
}

contract MockFourExtensionImpl is ERC721Extension {
    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Extension_init(_upgradeAdmin);
    }

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG() | BEFORE_TRANSFER_FLAG() | BEFORE_BURN_FLAG() | BEFORE_APPROVE_FLAG();
    }
}

contract MockOneExtensionImpl20 is ERC20Extension {
    constructor() {}

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_TRANSFER_FLAG();
    }
}

contract MockFourExtensionImpl20 is ERC20Extension {
    constructor() {}

    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG() | BEFORE_TRANSFER_FLAG() | BEFORE_BURN_FLAG() | BEFORE_APPROVE_FLAG();
    }
}
