// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/common/IFeeConfig.sol";
import {IPermission} from "../../interface/common/IPermission.sol";
import {ERC20Hook} from "../ERC20Hook.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

import {AllowlistMintHookERC20Storage} from "../../storage/hook/mint/AllowlistMintHookERC20Storage.sol";

contract AllowlistMintHookERC20 is IFeeConfig, ERC20Hook {
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

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error AllowlistMintHookNotAuthorized();

    /// @notice Emitted on an attempt to mint when there is no more available supply to mint.
    error AllowlistMintHookNotEnoughSupply(address token);

    /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
    error AllowlistMintHookNotInAllowlist(address token, address claimer);

    /// @notice Emitted when incorrect native token value is sent.
    error AllowlistMintHookIncorrectValueSent();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert AllowlistMintHookNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC20Hook_init(_upgradeAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "bytes32[]";
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfig(address _token) external view returns (FeeConfig memory) {
        return AllowlistMintHookERC20Storage.data().feeConfig[_token];
    }

    /// @notice Returns the active claim condition.
    function getClaimCondition(address _token) external view returns (ClaimCondition memory) {
        return AllowlistMintHookERC20Storage.data().claimCondition[_token];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return quantityToMint The quantity of tokens to mint.s
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistMintHookERC20Storage.Data storage data = AllowlistMintHookERC20Storage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (condition.availableSupply == 0) {
            revert AllowlistMintHookNotEnoughSupply(token);
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert AllowlistMintHookNotInAllowlist(token, _claimer);
            }
        }

        quantityToMint = uint96(_quantity);
        // `price` is interpreted as price per 1 ether unit of the ERC20 tokens.
        uint256 totalPrice = (_quantity * condition.price) / 1 ether;

        data.claimCondition[token].availableSupply -= _quantity;

        _collectPrice(totalPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the claim condition for.
     *  @param _claimCondition The claim condition to set.
     */
    function setClaimCondition(address _token, ClaimCondition memory _claimCondition) public onlyAdmin(_token) {
        AllowlistMintHookERC20Storage.data().claimCondition[_token] = _claimCondition;
        emit ClaimConditionUpdate(_token, _claimCondition);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        AllowlistMintHookERC20Storage.data().feeConfig[_token] = _config;
        emit DefaultFeeConfigUpdate(_token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distributes the sale value of minting a token.
    function _collectPrice(uint256 _totalPrice) internal {
        if (msg.value != _totalPrice) {
            revert AllowlistMintHookIncorrectValueSent();
        }
        if (_totalPrice == 0) {
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = AllowlistMintHookERC20Storage.data().feeConfig[token];

        uint256 platformFees = 0;
        if (feeConfig.platformFeeRecipient != address(0)) {
            platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        }
        if (platformFees > 0) {
            SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
        }
        SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
    }
}
