// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";

import {Ownable} from "@solady/auth/Ownable.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library SignatureMintStorage {
    /// @custom:storage-location erc7201:signature.mint.storage
    bytes32 public constant SIGNATURE_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("signature.mint.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(bytes32 => bool) uidUsed;
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

    struct SignatureMintParamsERC20 {
        SignatureMintRequestERC20 request;
        bytes signature;
    }

    struct SaleConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error SignatureMintIncorrectNativeTokenSent();
    error SigantureMintRequestExpired();
    error SignatureMintRequestUidReused();
    error SignatureMintRequestInvalidToken();
    error SignatureMintRequestMismatch();
    error SignatureMintRequestUnauthorizedSignature();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC20 = keccak256(
        "SignatureMintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](2);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC20.selector, CallType.CALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _signatureMintStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

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

        if (_signatureMintStorage().uidUsed[_req.uid]) {
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

        if (Ownable(_req.token).owner() != signer) {
            revert SignatureMintRequestUnauthorizedSignature();
        }

        _signatureMintStorage().uidUsed[_req.uid] = true;

        _distributeMintPrice(_req.recipient, _req.currency, (_req.quantity * _req.pricePerUnit) / 1e18);
    }

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

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SignatureMintERC20";
        version = "1";
    }

    function _signatureMintStorage() internal pure returns (SignatureMintStorage.Data storage) {
        return SignatureMintStorage.data();
    }
}
