// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/common/IFeeConfig.sol";
import {IPermission} from "../../interface/common/IPermission.sol";
import {ERC1155Hook} from "../ERC1155Hook.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

import {AllowlistMintHookERC1155Storage} from "../../storage/hook/mint/AllowlistMintHookERC1155Storage.sol";

contract AllowlistMintHookERC1155 is IFeeConfig, ERC1155Hook {
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
    event ClaimConditionUpdate(address indexed token, uint256 id, ClaimCondition claimCondition);

    /// @notice Emitted when the next token ID to mint is updated.
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error AllowlistMintHookNotAuthorized();

    /// @notice Emitted when minting invalid quantity of tokens.
    error AllowlistMintHookInvalidQuantity();

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
        __ERC1155Hook_init(_upgradeAdmin);
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
    function getFeeConfigForToken(address _token, uint256 _id) external view returns (FeeConfig memory) {
        return AllowlistMintHookERC1155Storage.data().feeConfig[_token][_id];
    }

    /// @notice Returns the fee config for a token.
    function getDefaultFeeConfig(address _token) external view returns (FeeConfig memory) {
        return AllowlistMintHookERC1155Storage.data().feeConfig[_token][type(uint256).max];
    }

    /// @notice Returns the active claim condition.
    function getClaimCondition(address _token, uint256 _id) external view returns (ClaimCondition memory) {
        return AllowlistMintHookERC1155Storage.data().claimCondition[_token][_id];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _id The token ID being minted.
     *  @param _value The quantity of tokens to mint.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(address _claimer, uint256 _id, uint256 _value, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistMintHookERC1155Storage.Data storage data = AllowlistMintHookERC1155Storage.data();

        ClaimCondition memory condition = data.claimCondition[token][_id];

        if (_value == 0 || _value > condition.availableSupply) {
            revert AllowlistMintHookInvalidQuantity();
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

        tokenIdToMint = _id;
        quantityToMint = _value;

        data.claimCondition[token][_id].availableSupply -= _value;

        _collectPrice(condition.price * _value, _id);
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
    function setClaimCondition(address _token, uint256 _id, ClaimCondition memory _claimCondition)
        public
        onlyAdmin(_token)
    {
        AllowlistMintHookERC1155Storage.data().claimCondition[_token][_id] = _claimCondition;
        emit ClaimConditionUpdate(_token, _id, _claimCondition);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfigForToken(address _token, uint256 _id, FeeConfig memory _config) external onlyAdmin(_token) {
        AllowlistMintHookERC1155Storage.data().feeConfig[_token][_id] = _config;
        emit TokenFeeConfigUpdate(_token, _id, _config);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setDefaultFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        AllowlistMintHookERC1155Storage.data().feeConfig[_token][type(uint256).max] = _config;
        emit DefaultFeeConfigUpdate(_token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distributes the sale value of minting a token.
    function _collectPrice(uint256 _totalPrice, uint256 _id) internal {
        if (msg.value != _totalPrice) {
            revert AllowlistMintHookIncorrectValueSent();
        }
        if (_totalPrice == 0) {
            return;
        }

        AllowlistMintHookERC1155Storage.Data storage data = AllowlistMintHookERC1155Storage.data();

        address token = msg.sender;
        FeeConfig memory defaultFeeConfig = data.feeConfig[token][type(uint256).max];
        FeeConfig memory feeConfig = data.feeConfig[token][_id]; // overriden fee config

        // If there is no override-primarySaleRecipient, we will use the default primarySaleRecipient.
        if (feeConfig.primarySaleRecipient == address(0)) {
            feeConfig.primarySaleRecipient = defaultFeeConfig.primarySaleRecipient;
        }

        // If there is no override-platformFeeRecipient, we will use the default platformFee recipient and bps.
        if (feeConfig.platformFeeRecipient == address(0)) {
            feeConfig.platformFeeRecipient = defaultFeeConfig.platformFeeRecipient;
            feeConfig.platformFeeBps = defaultFeeConfig.platformFeeBps;
        }

        uint256 platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        if (platformFees > 0) {
            SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
        }
        SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
    }
}
