// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {console} from "forge-std/console.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";

import {LibString} from "@solady/utils/LibString.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BeforeMintCallbackERC721} from "../../../callback/BeforeMintCallbackERC721.sol";
import {BeforeMintWithSignatureCallbackERC721} from "../../../callback/BeforeMintWithSignatureCallbackERC721.sol";

library MintableStorage {

    /// @custom:storage-location erc7201:token.minting.mintable
    bytes32 public constant MINTABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.mintable.erc721")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // UID => whether it has been used
        mapping(bytes32 => bool) uidUsed;
        // sale config
        MintableERC721.SaleConfig saleConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = MINTABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract MintableERC721 is
    Module,
    EIP712,
    BeforeMintCallbackERC721,
    BeforeMintWithSignatureCallbackERC721,
    IInstallationCallback
{

    using ECDSA for bytes32;
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The request struct signed by an authorized party to mint tokens.
     *
     *  @param startTimestamp The timestamp at which the minting request is valid.
     *  @param endTimestamp The timestamp at which the minting request expires.
     *  @param currency The address of the currency used to pay for the minted tokens.
     *  @param pricePerUnit The price per unit of the minted tokens.
     *  @param uid A unique identifier for the minting request.
     */
    struct MintRequestERC721 {
        uint48 startTimestamp;
        uint48 endTimestamp;
        address currency;
        uint256 pricePerUnit;
        bytes32 uid;
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
    error MintableRequestOutOfTimeWindow();

    /// @dev Emitted when the minting request UID has been reused.
    error MintableRequestUidReused();

    /// @dev Emitted when the minting request token is invalid.
    error MintableRequestInvalidToken();

    /// @dev Emitted when the minting request does not match the expected values.
    error MintableRequestMismatch();

    /// @dev Emitted when the minting request signature is unauthorized.
    error MintableRequestUnauthorized();

    /// @dev Emitted when trying to fetch metadata for a token that has no metadata.
    error MintableNoMetadataForTokenId();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when a new metadata batch is uploaded.
    event NewMetadataBatch(uint256 indexed startTokenIdInclusive, uint256 indexed endTokenIdNonInclusive);

    /// @dev ERC-4906 Metadata Update.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_MINTABLE_ERC721 = keccak256(
        "MintRequestERC721(uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](3);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC721.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeMintWithSignatureERC721.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getSaleConfig.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setSaleConfig.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.eip712Domain.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.registerInstallationCallback = true;

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(address _to, uint256 _startTokenId, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        if (!OwnableRoles(address(this)).hasAllRoles(msg.sender, Role._MINTER_ROLE)) {
            revert MintableRequestUnauthorized();
        }
    }

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintWithSignatureERC721(address _to, uint256 _startTokenId, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        MintRequestERC721 memory _params = abi.decode(_data, (MintRequestERC721));

        _mintWithSignatureERC721(_params);
        console.log("gets in here");
        _distributeMintPrice(msg.sender, _params.currency, _quantity * _params.pricePerUnit);
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address primarySaleRecipient = abi.decode(data, (address));
        _mintableStorage().saleConfig = SaleConfig(primarySaleRecipient);
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address primarySaleRecipient) external pure returns (bytes memory) {
        return abi.encode(primarySaleRecipient);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                        Encode mint params
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded mint params, to be used in `beforeMint` fallback function
    function encodeBytesBeforeMintWithSignatureERC721(MintRequestERC721 memory params)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig() external view returns (address primarySaleRecipient) {
        SaleConfig memory saleConfig = _mintableStorage().saleConfig;
        return (saleConfig.primarySaleRecipient);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        _mintableStorage().saleConfig = SaleConfig(_primarySaleRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints tokens on verifying a signature from an authorized party.
    function _mintWithSignatureERC721(MintRequestERC721 memory _req) internal {
        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert MintableRequestOutOfTimeWindow();
        }

        if (_mintableStorage().uidUsed[_req.uid]) {
            revert MintableRequestUidReused();
        }

        _mintableStorage().uidUsed[_req.uid] = true;
    }

    /// @dev Distributes the minting price to the primary sale recipient and platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert MintableIncorrectNativeTokenSent();
            }
            return;
        }
        console.log("passes initial test");

        SaleConfig memory saleConfig = _mintableStorage().saleConfig;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            console.log("native token detected");
            if (msg.value != _price) {
                revert MintableIncorrectNativeTokenSent();
            }
            console.log("shouldn't get here");
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price);
        } else {
            if (msg.value > 0) {
                revert MintableIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price);
        }
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
