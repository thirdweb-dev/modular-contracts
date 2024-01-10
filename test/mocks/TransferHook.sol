// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "src/extension/TokenHook.sol";
import "src/extension/Permission.sol";

contract TransferHook is TokenHook, Permission {
    uint8 public constant TRANSFER_ROLE_BITS = 2 ** 2;

    bool public isTransferrable;

    constructor(address _admin, bool _defaultTransferrable) {
        _setupRole(_admin, ADMIN_ROLE_BITS | TRANSFER_ROLE_BITS);
        isTransferrable = _defaultTransferrable;
    }

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_TRANSFER_FLAG;
    }

    function setTransferrable(bool _isTransferrable) external {
        require(hasRole(msg.sender, ADMIN_ROLE_BITS), "TransferHook: not admin");
        isTransferrable = _isTransferrable;
    }

    function beforeTransfer(address from, address to, uint256) external view override {
        if (!isTransferrable) {
            require(
                hasRole(from, TRANSFER_ROLE_BITS) || hasRole(to, TRANSFER_ROLE_BITS),
                "restricted to TRANSFER_ROLE holders"
            );
        }
    }
}
