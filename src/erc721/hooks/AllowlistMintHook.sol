// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IPermission} from "../../interface/extension/IPermission.sol";
import {TokenHook} from "../../extension/TokenHook.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";

contract AllowlistMintHook is TokenHook {

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The claim conditions for minting a token.
     *  @param price The price of minting one token.
     *  @param availableSupply The number of tokens that can be minted.
     *  @param allowlistMerkleRoot The allowlist of minters who are eligible to mint tokens
     */
    struct ClaimCondition {
        uint256 price;
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the claim condition for a given token is updated.
    event ClaimConditionUpdate(address indexed token, ClaimCondition claimCondition);

    /// @notice Emitted when the next token ID to mint is updated.
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint when there is no more available supply to mint.
    error NotEnouthSupply(address token);

    /// @notice Emitted on an attempt to mint when incorrect msg value is sent.
    error IncorrectValueSent(uint256 msgValue, uint256 price);

    /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
    error NotInAllowlist(address token, address claimer);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the next token ID to mint.
    mapping(address => uint256) private _nextTokenIdToMint;

    /// @notice Mapping from token => the claim conditions for minting the token.
    mapping(address => ClaimCondition) public claimCondition;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "bytes32[]";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return _nextTokenIdToMint[_token];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return mintParams The details around which to execute a mint.
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        override
        returns (MintParams memory mintParams)
    {
        address token = msg.sender;

        ClaimCondition memory condition = claimCondition[token];

        if (condition.availableSupply == 0) {
            revert NotEnouthSupply(token);
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert NotInAllowlist(token, _claimer);
            }
        }

        mintParams.quantityToMint = uint96(_quantity);
        mintParams.currency = NATIVE_TOKEN;
        mintParams.totalPrice = _quantity * condition.price;
        mintParams.tokenIdToMint = _nextTokenIdToMint[token]++;

        claimCondition[token].availableSupply -= _quantity;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the next token ID to mint for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the next token ID to mint for.
     *  @param _nextIdToMint The next token ID to mint.
     */
    function setNextIdToMint(address _token, uint256 _nextIdToMint) external onlyAdmin(_token) {
        _nextTokenIdToMint[_token] = _nextIdToMint;
        emit NextTokenIdUpdate(_token, _nextIdToMint);
    }

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the claim condition for.
     *  @param _claimCondition The claim condition to set.
     */
    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public onlyAdmin(_token) {
        claimCondition[_token] = _claimCondition;
        emit ClaimConditionUpdate(_token, _claimCondition);
    }
}
