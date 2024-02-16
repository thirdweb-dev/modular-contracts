// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/common/IFeeConfig.sol";
import {IPermission} from "../../interface/common/IPermission.sol";
import {ERC721Extension} from "../ERC721Extension.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

import {AllowlistNewExtensionStorage} from "../../storage/extension/mint/AllowlistNewExtensionStorage.sol";

contract AllowlistNewExtension is IFeeConfig, ERC721Extension {
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

    /// @notice Emitted when caller is not token core admin.
    error AllowlistMintExtensionsNotAuthorized();

    /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
    error AllowlistMintExtensionNotInAllowlist(address token, address claimer);

    /// @notice Emitted when incorrect native token value is sent.
    error AllowlistMintExtensionIncorrectValueSent();

    /// @notice Emitted when minting invalid quantity of tokens.
    error AllowlistMintExtensionInvalidQuantity();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Extension_init(_upgradeAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all extension functions implemented by this extension contract.
    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = BEFORE_MINT_FLAG();
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint extension.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "bytes32[]";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return AllowlistNewExtensionStorage.data().nextTokenIdToMint[_token];
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfigForToken(address _token, uint256 _id) external view returns (FeeConfig memory) {
        return AllowlistNewExtensionStorage.data().feeConfig[_token][_id];
    }

    /// @notice Returns the fee config for a token.
    function getDefaultFeeConfig(address _token) external view returns (FeeConfig memory) {
        return AllowlistNewExtensionStorage.data().feeConfig[_token][type(uint256).max];
    }

    /// @notice Returns the active claim condition.
    function getClaimCondition(address _token) external view returns (ClaimCondition memory) {
        return AllowlistNewExtensionStorage.data().claimCondition[_token];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT EXTENSION
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint extension that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint extension.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistNewExtensionStorage.Data storage data = AllowlistNewExtensionStorage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (_quantity == 0 || _quantity > condition.availableSupply) {
            revert AllowlistMintExtensionInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert AllowlistMintExtensionNotInAllowlist(token, _claimer);
            }
        }

        tokenIdToMint = data.nextTokenIdToMint[token];
        data.nextTokenIdToMint[token] += _quantity;

        quantityToMint = _quantity;

        data.claimCondition[token].availableSupply -= _quantity;

        _collectPrice(condition.price * _quantity, tokenIdToMint);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the next token ID to mint for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _nextIdToMint The next token ID to mint.
     */
    function setNextIdToMint(uint256 _nextIdToMint) external {
        address token = msg.sender;

        AllowlistNewExtensionStorage.data().nextTokenIdToMint[token] = _nextIdToMint;
        emit NextTokenIdUpdate(token, _nextIdToMint);
    }

    /**
     *  @notice Sets the claim condition for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _claimCondition The claim condition to set.
     */
    function setClaimCondition(ClaimCondition memory _claimCondition) public {
        address token = msg.sender;

        AllowlistNewExtensionStorage.data().claimCondition[token] = _claimCondition;
        emit ClaimConditionUpdate(token, _claimCondition);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _config The fee config for the token.
     */
    function setFeeConfigForToken(uint256 _id, FeeConfig memory _config) external {
        address token = msg.sender;

        AllowlistNewExtensionStorage.data().feeConfig[token][_id] = _config;
        emit TokenFeeConfigUpdate(token, _id, _config);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _config The fee config for the token.
     */
    function setDefaultFeeConfig(FeeConfig memory _config) external {
        address token = msg.sender;

        AllowlistNewExtensionStorage.data().feeConfig[token][type(uint256).max] = _config;
        emit DefaultFeeConfigUpdate(token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distributes the sale value of minting a token.
    function _collectPrice(uint256 _totalPrice, uint256 _id) internal {
        if (msg.value != _totalPrice) {
            revert AllowlistMintExtensionIncorrectValueSent();
        }
        if (_totalPrice == 0) {
            return;
        }

        AllowlistNewExtensionStorage.Data storage data = AllowlistNewExtensionStorage.data();

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
