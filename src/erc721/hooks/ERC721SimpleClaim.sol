// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

/// This is an example claim mechanism contract that calls that calls into the ERC721Core contract's mint API.
///
/// Note that this contract is designed to hold "shared state" i.e. it is deployed once by anyone, and can be
/// used by anyone for their copy of `ERC721Core`.

import { TokenHook } from "../../extension/TokenHook.sol";
import { Permission } from "../../extension/Permission.sol";
import { RoyaltyShared } from "../../extension/RoyaltyShared.sol";
import { MerkleProof } from "../../lib/MerkleProof.sol";
import { Strings } from "../../lib/Strings.sol";

contract ERC721SimpleClaim is TokenHook, RoyaltyShared {

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
    error NotTransferrable(address from, address to, uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextTokenIdToMint;
    mapping(address => string) public baseURI;
    mapping(address => ClaimCondition) public claimCondition;

    constructor() {}

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _id) external view returns (string memory) {
        return string(abi.encodePacked(baseURI[msg.sender], _id.toString()));
    }

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBaseURI(address _token, string memory _baseURI) external {
        // Checks `ADMIN_ROLE_BITS=0`
        if(!Permission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert Unauthorized(msg.sender, _token);
        }

        baseURI[_token] = _baseURI;

        emit BaseURISet(_token, _baseURI);
    }

    function beforeMint(address _claimer, uint256 _quantity, bytes memory _data) external payable override returns (uint256 tokenIdToMint) {

        address token = msg.sender;

        ClaimCondition memory condition = claimCondition[token];

        if(condition.availableSupply == 0) {
            revert NotEnouthSupply(token);
        }

        uint256 totalPrice = condition.price * _quantity;
        if(msg.value != totalPrice) {
            revert IncorrectValueSent(msg.value, totalPrice);
        }

        if(condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_data, (bytes32[]));
            
            (bool isAllowlisted, ) = MerkleProof.verify(
                allowlistProof,
                condition.allowlistMerkleRoot,
                keccak256(
                    abi.encodePacked(
                        _claimer
                    )
                )
            );
            if(!isAllowlisted) {
                revert NotInAllowlist(token, _claimer);
            }
        }
        
        claimCondition[token].availableSupply -= _quantity;

        (bool success,) = condition.saleRecipient.call{value: msg.value}("");
        if(!success) {
            revert NativeTransferFailed(condition.saleRecipient, msg.value);
        }

        tokenIdToMint = nextTokenIdToMint;
        nextTokenIdToMint += _quantity;
    }

    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public {
        // Checks `ADMIN_ROLE_BITS=0`
        if(!Permission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert Unauthorized(msg.sender, _token);
        }
        claimCondition[_token] = _claimCondition;

        emit ClaimConditionSet(_token, _claimCondition);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _canSetRoyaltyInfo() internal view override returns (bool) {
        return Permission(msg.sender).hasRole(msg.sender, ADMIN_ROLE_BITS);
    }
}