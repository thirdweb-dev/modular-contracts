// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BeforeMintCallbackERC721} from "../../../callback/BeforeMintCallbackERC721.sol";
import {OnTokenURICallback} from "../../../callback/OnTokenURICallback.sol";

library MintableStorage {
    /// @custom:storage-location erc7201:token.minting.mintable
    bytes32 public constant MINTABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.mintable.erc721")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => UID => whether it has been used
        mapping(address => mapping(bytes32 => bool)) uidUsed;
        // token => sale config
        mapping(address => MintableERC721.SaleConfig) saleConfig;
        // token => tokenID => tokenURI
        mapping(address => mapping(uint256 => string)) tokenURI;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = MINTABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract MintableERC721 is ModularExtension, EIP712, BeforeMintCallbackERC721, OnTokenURICallback {
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
     *  @param metadataURIs The URIs of the metadata for each minted token.
     *  @param uid A unique identifier for the minting request.
     */
    struct MintRequestERC721 {
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        address currency;
        uint256 pricePerUnit;
        string[] metadataURIs;
        bytes32 uid;
    }

    /**
     *  @notice The parameters sent to the `beforeMintERC20` callback function.
     *
     *  @param request The minting request.
     *  @param signature The signature produced from signing the minting request.
     */
    struct MintParamsERC721 {
        MintRequestERC721 request;
        bytes signature;
    }

    /**
     *  @notice The configuration of a token's sale value distribution.
     *
     *  @param primarySaleRecipient The address that receives the primary sale value.
     */
    struct SaleConfig {
        address primarySaleRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when an incorrect amount of native token is sent.
    error MintableIncorrectNativeTokenSent();

    /// @dev Emitted when the minting request has expired.
    error MintableRequestExpired();

    /// @dev Emitted when the minting request UID has been reused.
    error MintableRequestUidReused();

    /// @dev Emitted when the minting request token is invalid.
    error MintableRequestInvalidToken();

    /// @dev Emitted when the minting request does not match the expected values.
    error MintableRequestMismatch();

    /// @dev Emitted when the minting request signature is unauthorized.
    error MintableRequestUnauthorizedSignature();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when a token's metadata URI is updated.
    event MintableTokenURIUpdated(uint256 tokenId, string tokenURI);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_MINTABLE_ERC721 = keccak256(
        "MintRequestERC721(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,string[] metadataURIs,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](3);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC721.selector, CallType.CALL);
        config.callbackFunctions[1] = CallbackFunction(this.onTokenURI.selector, CallType.STATICCALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: Role._MANAGER_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.setTokenURI.selector,
            callType: CallType.CALL,
            permissionBits: Role._MINTER_ROLE
        });

        config.requiredInterfaceId = 0x80ac58cd; // ERC721
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.tokenURI function.
    function onTokenURI(uint256 _tokenId) external view virtual override returns (string memory) {
        return _mintableStorage().tokenURI[msg.sender][_tokenId];
    }

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(
        address _caller,
        address _to,
        uint256 _startTokenId,
        uint256 _quantity,
        bytes memory _data
    ) external payable virtual override returns (bytes memory) {
        MintParamsERC721 memory _params = abi.decode(_data, (MintParamsERC721));
        _mintWithSignatureERC721(_to, _quantity, _startTokenId, _params.request, _params.signature);
        _distributeMintPrice(_caller, _params.request.currency, _params.request.quantity * _params.request.pricePerUnit);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig(address _token) external view returns (address primarySaleRecipient) {
        SaleConfig memory saleConfig = _mintableStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        address token = msg.sender;
        _mintableStorage().saleConfig[token] = SaleConfig(_primarySaleRecipient);
    }

    /// @notice Sets the token URI for a token.
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) public {
        _mintableStorage().tokenURI[msg.sender][_tokenId] = _tokenURI;
        emit MintableTokenURIUpdated(_tokenId, _tokenURI);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints tokens on verifying a signature from an authorized party.
    function _mintWithSignatureERC721(
        address _expectedRecipient,
        uint256 _expectedAmount,
        uint256 _startTokenId,
        MintRequestERC721 memory _req,
        bytes memory _signature
    ) internal {
        if (_req.token != msg.sender) {
            revert MintableRequestInvalidToken();
        }

        if (
            _req.recipient != _expectedRecipient || _req.quantity != _expectedAmount
                || _req.metadataURIs.length != _expectedAmount
        ) {
            revert MintableRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert MintableRequestExpired();
        }

        if (_mintableStorage().uidUsed[_req.token][_req.uid]) {
            revert MintableRequestUidReused();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_MINTABLE_ERC721,
                    _req.token,
                    _req.startTimestamp,
                    _req.endTimestamp,
                    _req.recipient,
                    _req.quantity,
                    _req.currency,
                    _req.pricePerUnit,
                    _hashMetadataURIs(_req.metadataURIs),
                    _req.uid
                )
            )
        ).recover(_signature);

        if (!OwnableRoles(_req.token).hasAllRoles(signer, Role._MINTER_ROLE)) {
            revert MintableRequestUnauthorizedSignature();
        }

        _mintableStorage().uidUsed[_req.token][_req.uid] = true;

        uint256 len = _req.metadataURIs.length;
        uint256 tokenId = _startTokenId;
        for (uint256 i = 0; i < len; i++) {
            setTokenURI(tokenId + i, _req.metadataURIs[i]);
        }
    }

    /// @dev Distributes the minting price to the primary sale recipient and platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert MintableIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _mintableStorage().saleConfig[msg.sender];

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert MintableIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price);
        }
    }

    /// @dev Hashes an array of metadata URIs.
    function _hashMetadataURIs(string[] memory metadataURIs) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](metadataURIs.length);

        for (uint256 i = 0; i < metadataURIs.length; i++) {
            hashes[i] = keccak256(bytes(metadataURIs[i]));
        }

        return keccak256(abi.encodePacked(hashes));
    }

    /// @dev Returns the domain name and version for EIP712.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "MintableERC721";
        version = "1";
    }

    function _mintableStorage() internal pure returns (MintableStorage.Data storage) {
        return MintableStorage.data();
    }
}
