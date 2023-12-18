// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.
///
/// Note that this contract is designed to hold "shared state" i.e. it is deployed once by anyone, and can be
/// used by anyone for their copy of `ERC721Core`.

import { ERC721Core } from "./ERC721Core.sol"; 
import { Permissions } from "./extension/Permissions.sol";

contract SimpleClaim {

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ClaimCondition {
        uint256 price;
        uint256 availableSupply;
        address saleRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimConditionSet(address indexed token, uint256 price, uint256 availableSupply, address saleRecipient);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, address token);
    error NotEnouthSupply(address token);
    error IncorrectValueSent(uint256 msgValue, uint256 price);
    error NativeTransferFailed(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => ClaimCondition) public claimCondition;

    constructor() {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function claim(address _token) public payable {

        ClaimCondition memory condition = claimCondition[_token];

        if(msg.value != condition.price) {
            revert IncorrectValueSent(msg.value, condition.price);
        }
        if(condition.availableSupply == 0) {
            revert NotEnouthSupply(_token);
        }

        condition.availableSupply -= 1;

        (bool success,) = condition.saleRecipient.call{value: msg.value}("");
        if(!success) {
            revert NativeTransferFailed(condition.saleRecipient, msg.value);
        }

        ERC721Core(_token).mint(msg.sender);
    }

    function setClaimCondition(address _token, uint256 _price, uint256 _availableSupply, address _saleRecipient) public {
        // Checks `ADMIN_ROLE=0`
        if(!Permissions(_token).hasRole(msg.sender, 0)) {
            revert Unauthorized(msg.sender, _token);
        }
        claimCondition[_token] = ClaimCondition(_price, _availableSupply, _saleRecipient);

        emit ClaimConditionSet(_token, _price, _availableSupply, _saleRecipient);
    }
}