// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library SignatureMintStorage {
    /// @custom:storage-location erc7201:token.minting.signature
    bytes32 public constant SIGNATURE_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.signature")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => UID => whether it has been used
        mapping(address => mapping(bytes32 => bool)) uidUsed;
        // token => sale config
        mapping(address => SignatureMintERC20.SaleConfig) saleConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SIGNATURE_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract SignatureMintERC20 is ModularExtension, EIP712 {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The request struct signed by an authorized party to mint tokens.
     *
     *  @param token The address of the token being minted.
     *  @param startTimestamp The timestamp at which the minting request is valid.
     *  @param endTimestamp The timestamp at which the minting request expires.
     *  @param recipient The address that will receive the minted tokens.
     *  @param quantity The quantity of tokens to mint.
     *  @param currency The address of the currency used to pay for the minted tokens.
     *  @param pricePerUnit The price per unit of the minted tokens.
     *  @param uid A unique identifier for the minting request.
     */
    struct SignatureMintRequestERC20 {
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        address currency;
        uint256 pricePerUnit;
        bytes32 uid;
    }

    /**
     *  @notice The parameters sent to the `beforeMintERC20` callback function.
     *
     *  @param request The minting request.
     *  @param signature The signature produced from signing the minting request.
     */
    struct SignatureMintParamsERC20 {
        SignatureMintRequestERC20 request;
        bytes signature;
    }

    /**
     *  @notice The configuration of a token's sale value distribution.
     *
     *  @param primarySaleRecipient The address that receives the primary sale value.
     *  @param platformFeeRecipient The address that receives the platform fee.
     *  @param platformFeeBps The basis points of the platform fee. 10_000 = 100%.
     */
    struct SaleConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when an incorrect amount of native token is sent.
    error SignatureMintIncorrectNativeTokenSent();

    /// @dev Emitted when the minting request has expired.
    error SigantureMintRequestExpired();

    /// @dev Emitted when the minting request UID has been reused.
    error SignatureMintRequestUidReused();

    /// @dev Emitted when the minting request token is invalid.
    error SignatureMintRequestInvalidToken();

    /// @dev Emitted when the minting request does not match the expected values.
    error SignatureMintRequestMismatch();

    /// @dev Emitted when the minting request signature is unauthorized.
    error SignatureMintRequestUnauthorizedSignature();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC20 = keccak256(
        "SignatureMintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](2);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC20.selector, CallType.CALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: Role._MINTER_ROLE
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC20Core.mint function.
    function beforeMintERC20(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        SignatureMintParamsERC20 memory _params = abi.decode(_data, (SignatureMintParamsERC20));
        _mintWithSignatureERC20(_to, _quantity, _params.request, _params.signature);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _signatureMintStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _signatureMintStorage().saleConfig[token] =
            SaleConfig(_primarySaleRecipient, _platformFeeRecipient, _platformFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints tokens on verifying a signature from an authorized party.
    function _mintWithSignatureERC20(
        address _expectedRecipient,
        uint256 _expectedAmount,
        SignatureMintRequestERC20 memory _req,
        bytes memory _signature
    ) internal {
        if (_req.token != msg.sender) {
            revert SignatureMintRequestInvalidToken();
        }

        if (_req.recipient != _expectedRecipient || _req.quantity != _expectedAmount) {
            revert SignatureMintRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert SigantureMintRequestExpired();
        }

        if (_signatureMintStorage().uidUsed[_req.token][_req.uid]) {
            revert SignatureMintRequestUidReused();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_SIGNATURE_MINT_ERC20,
                    _req.token,
                    _req.startTimestamp,
                    _req.endTimestamp,
                    _req.recipient,
                    _req.quantity,
                    _req.currency,
                    _req.pricePerUnit,
                    _req.uid
                )
            )
        ).recover(_signature);

        if (!OwnableRoles(_req.token).hasAllRoles(signer, Role._MINTER_ROLE)) {
            revert SignatureMintRequestUnauthorizedSignature();
        }

        _signatureMintStorage().uidUsed[_req.token][_req.uid] = true;

        _distributeMintPrice(_req.recipient, _req.currency, (_req.quantity * _req.pricePerUnit) / 1e18);
    }

    /// @dev Distributes the minting price to the primary sale recipient and platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert SignatureMintIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _signatureMintStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert SignatureMintIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    /// @dev Returns the domain name and version for EIP712.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SignatureMintERC20";
        version = "1";
    }

    function _signatureMintStorage() internal pure returns (SignatureMintStorage.Data storage) {
        return SignatureMintStorage.data();
    }
}
