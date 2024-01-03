// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// NOTE: This contract is for testing purposes only. It is not intended to be used in production.
///       It is the same as ERC721SimpleClaim, but with the bug that is does not decrement available
///       supply after a claim.

import { ERC721Core } from "src/erc721/ERC721Core.sol"; 
import { Permissions } from "src/extension/Permissions.sol";
import { MerkleProof } from "src/lib/MerkleProof.sol";
import { Strings } from "src/lib/Strings.sol";

contract MockBuggySimpleClaim {

    using Strings for uint256;

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

    event BaseURISet(address indexed token, string baseURI);
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

    mapping(address => string) public baseURI;
    mapping(address => ClaimCondition) public claimCondition;

    constructor() {}

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 id) external view returns (string memory) {
        return string(abi.encodePacked(baseURI[msg.sender], id.toString()));
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBaseURI(address _token, string memory _baseURI) external {
        // Checks `ADMIN_ROLE=0`
        if(!Permissions(_token).hasRole(msg.sender, 0)) {
            revert Unauthorized(msg.sender, _token);
        }

        baseURI[_token] = _baseURI;

        emit BaseURISet(_token, _baseURI);
    }

    function beforeMint(address claimer, uint256, bytes memory data) public payable {

        address token = msg.sender;
        bytes32[] memory allowlistProof = abi.decode(data, (bytes32[]));

        ClaimCondition memory condition = claimCondition[token];

        if(msg.value != condition.price) {
            revert IncorrectValueSent(msg.value, condition.price);
        }
        if(condition.availableSupply == 0) {
            revert NotEnouthSupply(token);
        }

        (bool isAllowlisted, ) = MerkleProof.verify(
            allowlistProof,
            condition.allowlistMerkleRoot,
            keccak256(
                abi.encodePacked(
                    claimer
                )
            )
        );
        if(!isAllowlisted) {
            revert NotInAllowlist(token, claimer);
        }
        
        // BUG: availableSupply is not decremented

        (bool success,) = condition.saleRecipient.call{value: msg.value}("");
        if(!success) {
            revert NativeTransferFailed(condition.saleRecipient, msg.value);
        }
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