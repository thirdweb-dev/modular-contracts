// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {IMintRequestERC1155} from "../../interface/extension/IMintRequestERC1155.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {ECDSA} from "../../lib/ECDSA.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {EIP712} from "../../extension/EIP712.sol";
import {ERC1155Hook} from "./ERC1155Hook.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

contract SignatureMintHook is IFeeConfig, IMintRequestERC1155, EIP712, ERC1155Hook {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The EIP-712 typehash for the mint request struct.
    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,uint256 tokenId,address to,uint256 quantity,uint256 pricePerToken,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
    );

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error SignatureMintHookNotAuthorized();

    /// @notice Emitted when minting invalid quantity.
    error SignatureMintHookInvalidQuantity();

    /// @notice Emitted when minting with an invalid mint request.
    error SignatureMintHookInvalidRequest();

    /// @notice Emitted when minting with an expired request.
    error SignatureMintHookRequestExpired();

    /// @notice Emitted when minting to an invalid recipient.
    error SignatureMintHookInvalidRecipient();

    /// @notice Emitted when incorrect native token value is sent.
    error SignatureMintHookIncorrectValueSent();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from request UID => whether the mint request is processed.
    mapping(bytes32 => bool) private minted;

    /// @notice Mapping from token => token-id => fee config for the token.
    mapping(address => mapping(uint256 => FeeConfig)) private _feeConfig;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert SignatureMintHookNotAuthorized();
        }
        _;
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
        argSignature = "address,uint256,address,uint256,uint256,address,uint128,uint128,bytes32,bytes";
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfigForToken(address _token, uint256 _id) external view returns (FeeConfig memory) {
        return _feeConfig[_token][_id];
    }

    /// @notice Returns the fee config for a token.
    function getDefaultFeeConfig(address _token) external view returns (FeeConfig memory) {
        return _feeConfig[_token][type(uint256).max];
    }

    /**
     *  @notice Verifies the mint request for minting a given token.
     *  @param _token The token address.
     *  @param _req The mint request.
     *  @param _signature The signature of the mint request.
     */
    function verify(address _token, MintRequestERC1155 memory _req, bytes memory _signature)
        public
        view
        returns (bool success, address signer)
    {
        signer = _recoverAddress(_req, _signature);
        success = !minted[_req.uid] && _token == _req.token && IPermission(_token).hasRole(signer, ADMIN_ROLE_BITS);
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
    function beforeMint(address _claimer, uint256 _id, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        override
        returns (MintParams memory mintParams)
    {
        address token = msg.sender;

        (MintRequestERC1155 memory req, bytes memory signature) = abi.decode(_encodedArgs, (MintRequestERC1155, bytes));
        if (req.quantity != _quantity) {
            revert SignatureMintHookInvalidQuantity();
        }

        mintParams.tokenIdToMint = _id;
        mintParams.quantityToMint = uint96(_quantity);
        mintParams.totalPrice = req.pricePerToken * _quantity;
        mintParams.currency = req.currency;

        _processRequest(token, req, signature);
        _collectPrice(_claimer, _id, req.pricePerToken * _quantity, req.currency);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfigForToken(address _token, uint256 _id, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token][_id] = _config;
        emit FeeConfigUpdateERC1155(_token, _id, _config);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setDefaultFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token][type(uint256).max] = _config;
        emit FeeConfigUpdateERC1155(_token, type(uint256).max, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _collectPrice(address _minter, uint256 _id, uint256 _totalPrice, address _currency) internal {
        if (_totalPrice == 0) {
            if (msg.value > 0) {
                revert SignatureMintHookIncorrectValueSent();
            }
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = _feeConfig[token][_id];

        if (feeConfig.primarySaleRecipient == address(0) || feeConfig.platformFeeRecipient == address(0)) {
            feeConfig = _feeConfig[token][type(uint256).max];
        }

        bool payoutPlatformFees = feeConfig.platformFeeBps > 0 && feeConfig.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if (payoutPlatformFees) {
            platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            if (msg.value != _totalPrice) {
                revert SignatureMintHookIncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        } else {
            if (msg.value > 0) {
                revert SignatureMintHookIncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        }
    }

    /// @dev Returns the domain name and version for the EIP-712 domain separator
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SignatureMintERC1155";
        version = "1";
    }

    /// @dev Returns the address of the signer of the mint request.
    function _recoverAddress(MintRequestERC1155 memory _req, bytes memory _signature) internal view returns (address) {
        return _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _req.token,
                    _req.tokenId,
                    _req.to,
                    _req.quantity,
                    _req.pricePerToken,
                    _req.currency,
                    _req.validityStartTimestamp,
                    _req.validityEndTimestamp,
                    _req.uid
                )
            )
        ).recover(_signature);
    }

    /// @dev Verified and processes the mint request as used for minting a token.
    function _processRequest(address _token, MintRequestERC1155 memory _req, bytes memory _signature) internal {
        bool success;
        address signer;
        (success, signer) = verify(_token, _req, _signature);

        if (!success) {
            revert SignatureMintHookInvalidRequest();
        }

        if (_req.validityStartTimestamp > block.timestamp || block.timestamp > _req.validityEndTimestamp) {
            revert SignatureMintHookRequestExpired();
        }
        if (_req.to == address(0)) {
            revert SignatureMintHookInvalidRecipient();
        }
        if (_req.quantity == 0) {
            revert SignatureMintHookInvalidQuantity();
        }

        minted[_req.uid] = true;
    }
}
