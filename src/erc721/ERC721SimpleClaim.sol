// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.
///
/// Note that this contract is designed to hold "shared state" i.e. it is deployed once by anyone, and can be
/// used by anyone for their copy of `ERC721Core`.

import { ERC721Core } from "./ERC721Core.sol"; 
import { Permissions } from "../extension/Permissions.sol";
import { MerkleProof } from "../lib/MerkleProof.sol";

contract ERC721SimpleClaim {

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ClaimCondition {
        uint256 price;
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        address saleRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimConditionSet(address indexed token, ClaimCondition claimCondition);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller, address token);
    error NotEnouthSupply(address token);
    error IncorrectValueSent(uint256 msgValue, uint256 price);
    error NotInAllowlist(address token, address claimer);
    error NativeTransferFailed(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => ClaimCondition) public claimCondition;

    constructor() {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function claim(address _token, bytes32[] calldata _allowlistProof) public payable {

        ClaimCondition memory condition = claimCondition[_token];
        address claimer = msg.sender;

        if(msg.value != condition.price) {
            revert IncorrectValueSent(msg.value, condition.price);
        }
        if(condition.availableSupply == 0) {
            revert NotEnouthSupply(_token);
        }

        (bool isAllowlisted, ) = MerkleProof.verify(
            _allowlistProof,
            condition.allowlistMerkleRoot,
            keccak256(
                abi.encodePacked(
                    claimer
                )
            )
        );
        if(!isAllowlisted) {
            revert NotInAllowlist(_token, claimer);
        }

        condition.availableSupply -= 1;

        (bool success,) = condition.saleRecipient.call{value: msg.value}("");
        if(!success) {
            revert NativeTransferFailed(condition.saleRecipient, msg.value);
        }

        ERC721Core(_token).mint(claimer);
    }

    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public {
        // Checks `ADMIN_ROLE=0`
        if(!Permissions(_token).hasRole(msg.sender, 0)) {
            revert Unauthorized(msg.sender, _token);
        }
        claimCondition[_token] = _claimCondition;

        emit ClaimConditionSet(_token, _claimCondition);
    }
}