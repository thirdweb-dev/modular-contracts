// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/common/IFeeConfig.sol";
import {IPermission} from "../../interface/common/IPermission.sol";
import {ERC20Extension} from "../ERC20Extension.sol";
import {MerkleProofLib} from "../../lib/MerkleProofLib.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

import {AllowlistMintExtensionERC20Storage} from "../../storage/extension/mint/AllowlistMintExtensionERC20Storage.sol";

contract AllowlistMintExtensionERC20 is IFeeConfig, ERC20Extension {
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
    error AllowlistMintExtensionsNotAuthorized();

    /// @notice Emitted when minting invalid quantity of tokens.
    error AllowlistMintExtensionInvalidQuantity();

    /// @notice Emitted on an attempt to mint when the claimer is not in the allowlist.
    error AllowlistMintExtensionNotInAllowlist(address token, address claimer);

    /// @notice Emitted when incorrect native token value is sent.
    error AllowlistMintExtensionIncorrectValueSent();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC20Extension_init(_upgradeAdmin);
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

    /// @notice Returns the fee config for a token.
    function getFeeConfig(address _token) external view returns (FeeConfig memory) {
        return AllowlistMintExtensionERC20Storage.data().feeConfig[_token];
    }

    /// @notice Returns the active claim condition.
    function getClaimCondition(address _token) external view returns (ClaimCondition memory) {
        return AllowlistMintExtensionERC20Storage.data().claimCondition[_token];
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT EXTENSION
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint extension that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint extension.
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
        AllowlistMintExtensionERC20Storage.Data storage data = AllowlistMintExtensionERC20Storage.data();

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
     *  @param _claimCondition The claim condition to set.
     */
    function setClaimCondition(ClaimCondition memory _claimCondition) public {
        address token = msg.sender;

        AllowlistMintExtensionERC20Storage.data().claimCondition[token] = _claimCondition;
        emit ClaimConditionUpdate(token, _claimCondition);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _config The fee config for the token.
     */
    function setDefaultFeeConfig(FeeConfig memory _config) external {
        address token = msg.sender;

        AllowlistMintExtensionERC20Storage.data().feeConfig[token] = _config;
        emit DefaultFeeConfigUpdate(token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distributes the sale value of minting a token.
    function _collectPrice(uint256 _totalPrice) internal {
        if (msg.value != _totalPrice) {
            revert AllowlistMintExtensionIncorrectValueSent();
        }
        if (_totalPrice == 0) {
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = AllowlistMintExtensionERC20Storage.data().feeConfig[token];

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
