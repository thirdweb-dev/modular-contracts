// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { ERC1155Hook } from "../ERC1155Hook.sol";
import { IPermission } from "../../interface/common/IPermission.sol";

contract BeforeTransferHookBlacklistERC1155 is ERC1155Hook {
    mapping(address => bool) public isBlacklisted;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an address is blacklisted.
    event AddressBlacklisted(address indexed _address, bool _isBlacklisted);
   
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeTransferHookInvalidCaller();

    error BeforeTransferHookNotToken();

    error BeforeTransferHookBlacklisted();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC1155Hook_init(_upgradeAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooks() external pure override returns (uint256) {
        return BEFORE_TRANSFER_FLAG();
    }


    /*//////////////////////////////////////////////////////////////
                            BEFORE TRANSFER HOOK
    //////////////////////////////////////////////////////////////*/

    function beforeTransfer(
        address from,
        address to,
        uint256, // space holder for id
        uint256 // space holder for value
    ) external override {
        address token = msg.sender;
        if (token != msg.sender) {
            revert BeforeTransferHookNotToken();
        }

        if (isBlacklisted[from] || isBlacklisted[to]) {
            revert BeforeTransferHookBlacklisted();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function blacklistAddress(address _address) external  {
        isBlacklisted[_address] = true;
        emit AddressBlacklisted(_address, true);
    }

    function blacklistManyAddress(address[] calldata _addresses) external {
        for (uint i = 0; i < _addresses.length; i++) {
            isBlacklisted[_addresses[i]] = true;
            emit AddressBlacklisted(_addresses[i], true);
        }
    }

    function unblacklistAddress(address _address) external  {
        if (isBlacklisted[_address]) { // Check if the address is currently blacklisted
                isBlacklisted[_address] = false;
                emit AddressBlacklisted(_address, false);
        }
    }

    function unblacklistManyAddress(address[] calldata _addresses) external {
        for (uint i = 0; i < _addresses.length; i++) {
            if (isBlacklisted[_addresses[i]]) { // Check if the address is currently blacklisted
                isBlacklisted[_addresses[i]] = false;
                emit AddressBlacklisted(_addresses[i], false);
            }
        }
    }

}