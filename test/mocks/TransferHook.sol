// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/erc721/ERC721Hooks.sol";
import "src/extension/Permissions.sol";

contract TransferHook is Permissions {

    using BitMaps for BitMaps.BitMap;

    uint8 public constant TRANSFER_ROLE = 1;

    bool public isTransferrable;

    constructor(address _admin, bool _defaultTransferrable) {
        _hasRole[_admin].set(ADMIN_ROLE);
        _hasRole[_admin].set(TRANSFER_ROLE);
        isTransferrable = _defaultTransferrable;
    }

    function setTransferrable(bool _isTransferrable) external {
        require(hasRole(msg.sender, ADMIN_ROLE), "TransferHook: not admin");
        isTransferrable = _isTransferrable;
    }

    function beforeTransfer(address from, address to, uint256) external view {
        if (!isTransferrable) {
            require(hasRole(from, TRANSFER_ROLE) || hasRole(to, TRANSFER_ROLE), "restricted to TRANSFER_ROLE holders");
        }
    }
}