// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.
///
/// Note that this contract is designed to hold "shared state" i.e. it is deployed once by anyone, and can be
/// used by anyone for their copy of `ERC721Core`.

import { Permission } from "../extension/Permission.sol";
import { MerkleProof } from "../lib/MerkleProof.sol";
import { Strings } from "../lib/Strings.sol";

contract ERC721SimpleClaim {

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
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant ADMIN_ROLE = 2 ** 1;

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
        if(!Permission(_token).hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, _token);
        }

        baseURI[_token] = _baseURI;

        emit BaseURISet(_token, _baseURI);
    }

    function beforeMint(address claimer, uint256, bytes memory data) public payable {

        address token = msg.sender;

        ClaimCondition memory condition = claimCondition[token];

        if(msg.value != condition.price) {
            revert IncorrectValueSent(msg.value, condition.price);
        }
        if(condition.availableSupply == 0) {
            revert NotEnouthSupply(token);
        }

        if(condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(data, (bytes32[]));
            
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
        }
        
        claimCondition[token].availableSupply -= 1;

        (bool success,) = condition.saleRecipient.call{value: msg.value}("");
        if(!success) {
            revert NativeTransferFailed(condition.saleRecipient, msg.value);
        }
    }

    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public {
        // Checks `ADMIN_ROLE=0`
        if(!Permission(_token).hasRole(msg.sender, ADMIN_ROLE)) {
            revert Unauthorized(msg.sender, _token);
        }
        claimCondition[_token] = _claimCondition;

        emit ClaimConditionSet(_token, _claimCondition);
    }
}