// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/erc721/ERC721Hooks.sol";
import "src/extension/Permissions.sol";

contract TransferHook is Permissions {

    using BitMaps for BitMaps.BitMap;

    uint8 public constant TRANSFER_ROLE_BITS = 2 ** 2;

    bool public isTransferrable;

    constructor(address _admin, bool _defaultTransferrable) {
        _setupRole(_admin, ADMIN_ROLE_BITS | TRANSFER_ROLE_BITS);
        isTransferrable = _defaultTransferrable;
    }

    function setTransferrable(bool _isTransferrable) external {
        require(hasRole(msg.sender, ADMIN_ROLE_BITS), "TransferHook: not admin");
        isTransferrable = _isTransferrable;
    }

    function beforeTransfer(address from, address to, uint256) external view {
        if (!isTransferrable) {
            require(hasRole(from, TRANSFER_ROLE_BITS) || hasRole(to, TRANSFER_ROLE_BITS), "restricted to TRANSFER_ROLE holders");
        }
    }
}