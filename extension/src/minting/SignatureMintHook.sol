// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";

import {Ownable} from "@solady/auth/Ownable.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library SignatureMintHookStorage {
    /// @custom:storage-location erc7201:signature.mint.hook.storage
    bytes32 public constant SIGNATURE_MINT_HOOK_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("signature.mint.hook.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(bytes32 => bool) uidUsed;
        mapping(address => SignatureMintHook.SaleConfig) saleConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SIGNATURE_MINT_HOOK_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract SignatureMintHook is IExtensionContract, EIP712 {
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

    struct SignatureMintRequestERC721 {
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        address currency;
        uint256 pricePerUnit;
        bytes32 uid;
    }

    struct SignatureMintRequestERC1155 {
        uint256 tokenId;
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

    struct SignatureMintParamsERC721 {
        SignatureMintRequestERC721 request;
        bytes signature;
    }

    struct SignatureMintParamsERC1155 {
        SignatureMintRequestERC1155 request;
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

    error MintHookUnrecognizedParams();
    error MintHookIncorrectNativeTokenSent();
    error MintHookRequestExpired();
    error MintHookRequestUidReused();
    error MintHookRequestInvalidToken();
    error MintHookRequestMismatch();
    error MintHookRequestUnauthorizedSignature();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC20 = keccak256(
        "SignatureMintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC721 = keccak256(
        "SignatureMintRequestERC721(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC1155 = keccak256(
        "SignatureMintRequestERC1155(uint256 tokenId,address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](3);
        config.extensionABI = new ExtensionFunction[](2);

        config.callbackFunctions[0] = this.beforeMintERC20.selector;
        config.callbackFunctions[1] = this.beforeMintERC721.selector;
        config.callbackFunctions[2] = this.beforeMintERC1155.selector;

        config.extensionABI[0] = ExtensionFunction({
            selector: this.getSaleConfig.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[1] =
            ExtensionFunction({selector: this.setSaleConfig.selector, callType: CallType.CALL, permissioned: false});
    }

    function beforeMintERC20(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        SignatureMintParamsERC20 memory _params = abi.decode(_data, (SignatureMintParamsERC20));
        _mintWithSignatureERC20(_to, _quantity, _params.request, _params.signature);
    }

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        SignatureMintParamsERC721 memory _params = abi.decode(_data, (SignatureMintParamsERC721));
        _mintWithSignatureERC721(_to, _quantity, _params.request, _params.signature);
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        SignatureMintParamsERC1155 memory _params = abi.decode(_data, (SignatureMintParamsERC1155));
        _mintWithSignatureERC1155(_to, _quantity, _id, _params.request, _params.signature);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _signatureMintHookStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _signatureMintHookStorage().saleConfig[token] =
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
            revert MintHookRequestInvalidToken();
        }

        if (_req.recipient != _expectedRecipient || _req.quantity != _expectedAmount) {
            revert MintHookRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert MintHookRequestExpired();
        }

        if (_signatureMintHookStorage().uidUsed[_req.uid]) {
            revert MintHookRequestUidReused();
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
            revert MintHookRequestUnauthorizedSignature();
        }

        _signatureMintHookStorage().uidUsed[_req.uid] = true;

        _distributeMintPrice(_req.recipient, _req.currency, (_req.quantity * _req.pricePerUnit) / 1e18);
    }

    function _mintWithSignatureERC721(
        address _expectedRecipient,
        uint256 _expectedAmount,
        SignatureMintRequestERC721 memory _req,
        bytes memory _signature
    ) internal {
        if (_req.token != msg.sender) {
            revert MintHookRequestInvalidToken();
        }

        if (_req.recipient != _expectedRecipient || _req.quantity != _expectedAmount) {
            revert MintHookRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert MintHookRequestExpired();
        }

        if (_signatureMintHookStorage().uidUsed[_req.uid]) {
            revert MintHookRequestUidReused();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_SIGNATURE_MINT_ERC721,
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
            revert MintHookRequestUnauthorizedSignature();
        }

        _signatureMintHookStorage().uidUsed[_req.uid] = true;

        _distributeMintPrice(_req.recipient, _req.currency, _req.quantity * _req.pricePerUnit);
    }

    function _mintWithSignatureERC1155(
        address _expectedRecipient,
        uint256 _expectedAmount,
        uint256 _expectedTokenId,
        SignatureMintRequestERC1155 memory _req,
        bytes memory _signature
    ) internal {
        if (_req.token != msg.sender) {
            revert MintHookRequestInvalidToken();
        }

        if (
            _req.recipient != _expectedRecipient || _req.quantity != _expectedAmount || _req.tokenId != _expectedTokenId
        ) {
            revert MintHookRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert MintHookRequestExpired();
        }

        if (_signatureMintHookStorage().uidUsed[_req.uid]) {
            revert MintHookRequestUidReused();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_SIGNATURE_MINT_ERC1155,
                    _req.tokenId,
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
            revert MintHookRequestUnauthorizedSignature();
        }

        _signatureMintHookStorage().uidUsed[_req.uid] = true;

        _distributeMintPrice(_req.recipient, _req.currency, _req.quantity * _req.pricePerUnit);
    }

    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert MintHookIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _signatureMintHookStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert MintHookIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "MintHook";
        version = "1";
    }

    function _signatureMintHookStorage() internal pure returns (SignatureMintHookStorage.Data storage) {
        return SignatureMintHookStorage.data();
    }
}
