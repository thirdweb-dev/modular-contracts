// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BeforeMintCallbackERC721} from "../../../callback/BeforeMintCallbackERC721.sol";

library ClaimableStorage {
    /// @custom:storage-location erc7201:token.minting.claimable.erc721
    bytes32 public constant CLAIMABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.claimable.erc721")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token address => sale config: primary sale recipient, and platform fee recipient + BPS.
        mapping(address => ClaimableERC721.SaleConfig) saleConfig;
        // token => claim condition
        mapping(address => ClaimableERC721.ClaimCondition) claimCondition;
        // token => UID => whether it has been used
        mapping(address => mapping(bytes32 => bool)) uidUsed;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIMABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimableERC721 is ModularExtension, EIP712, BeforeMintCallbackERC721 {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Details for distributing the proceeds of a mint.
     *  @param primarySaleRecipient The address to which the total proceeds minus fees are sent.
     */
    struct SaleConfig {
        address primarySaleRecipient;
    }

    /**
     *  @notice Conditions under which tokens can be minted.
     *  @param availableSupply The total number of tokens that can be minted.
     *  @param allowlistMerkleRoot The allowlist of addresses who can mint tokens.
     *  @param pricePerUnit The price per token.
     *  @param currency The currency in which the price is denominated.
     *  @param startTimestamp The timestamp at which the minting window opens.
     *  @param endTimestamp The timestamp after which the minting window closes.
     *  @param auxData Use to store arbitrary data. i.e: merkle snapshot url
     */
    struct ClaimCondition {
        uint256 availableSupply;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
        string auxData;
    }

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
    struct ClaimRequestERC721 {
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
    struct ClaimParamsERC721 {
        ClaimRequestERC721 request;
        bytes signature;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when incorrect amount of native token is sent.
    error ClaimableIncorrectNativeTokenSent();

    /// @dev Emitted when the minting request token is invalid.
    error ClaimableRequestInvalidToken();

    /// @dev Emitted when the minting request does not match the expected values.
    error ClaimableRequestMismatch();

    /// @dev Emitted when the minting request has expired.
    error ClaimableRequestExpired();

    /// @dev Emitted when the minting request UID has been reused.
    error ClaimableRequestUidReused();

    /// @dev Emitted when the minting request signature is unauthorized.
    error ClaimableRequestUnauthorizedSignature();

    /// @dev Emitted when the mint is attempted outside the minting window.
    error ClaimableOutOfTimeWindow();

    /// @dev Emitted when the mint is out of supply.
    error ClaimableOutOfSupply();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_CLAIMABLE_ERC721 = keccak256(
        "ClaimRequestERC721(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,address currency,uint256 pricePerUnit,bytes32 uid)"
    );

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC721.selector, CallType.CALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: Role._MANAGER_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getClaimCondition.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setClaimCondition.selector,
            callType: CallType.CALL,
            permissionBits: Role._MINTER_ROLE
        });

        config.requiredInterfaceId = 0x80ac58cd; // ERC721
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(
        address _caller,
        address _to,
        uint256 _startTokenId,
        uint256 _quantity,
        bytes memory _data
    ) external payable virtual override returns (bytes memory) {
        ClaimParamsERC721 memory _params = abi.decode(_data, (ClaimParamsERC721));

        ClaimCondition memory condition = _claimWithSignatureERC721(_to, _quantity, _params.request, _params.signature);

        address currency = _params.request.currency != address(0) ? _params.request.currency : condition.currency;
        uint256 price =
            _params.request.pricePerUnit != type(uint256).max ? _params.request.pricePerUnit : condition.pricePerUnit;

        _distributeMintPrice(_caller, currency, price);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig(address _token) external view returns (address primarySaleRecipient) {
        SaleConfig memory saleConfig = _claimableStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        address token = msg.sender;
        _claimableStorage().saleConfig[token] = SaleConfig(_primarySaleRecipient);
    }

    /// @notice Returns the claim condition for a token.
    function getClaimCondition(address _token) external view returns (ClaimCondition memory claimCondition) {
        return _claimableStorage().claimCondition[_token];
    }

    /// @notice Sets the claim condition for a token.
    function setClaimCondition(ClaimCondition memory _claimCondition) external {
        address token = msg.sender;
        _claimableStorage().claimCondition[token] = _claimCondition;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints tokens on verifying a signature from an authorized party.
    function _claimWithSignatureERC721(
        address _expectedRecipient,
        uint256 _expectedAmount,
        ClaimRequestERC721 memory _req,
        bytes memory _signature
    ) internal returns (ClaimCondition memory condition) {
        condition = _claimableStorage().claimCondition[_req.token];

        if (_req.token != msg.sender) {
            revert ClaimableRequestInvalidToken();
        }

        if (_req.recipient != _expectedRecipient || _req.quantity != _expectedAmount) {
            revert ClaimableRequestMismatch();
        }

        if (block.timestamp < _req.startTimestamp || _req.endTimestamp <= block.timestamp) {
            revert ClaimableRequestExpired();
        }

        if (_claimableStorage().uidUsed[_req.token][_req.uid]) {
            revert ClaimableRequestUidReused();
        }

        if (block.timestamp < condition.startTimestamp || condition.endTimestamp <= block.timestamp) {
            revert ClaimableOutOfTimeWindow();
        }

        if (_req.quantity > condition.availableSupply) {
            revert ClaimableOutOfSupply();
        }

        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_CLAIMABLE_ERC721,
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
            revert ClaimableRequestUnauthorizedSignature();
        }

        _claimableStorage().uidUsed[_req.token][_req.uid] = true;
    }

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert ClaimableIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimableStorage().saleConfig[msg.sender];

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert ClaimableIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price);
        }
    }

    /// @dev Returns the domain name and version for EIP712.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "ClaimableERC721";
        version = "1";
    }

    function _claimableStorage() internal pure returns (ClaimableStorage.Data storage) {
        return ClaimableStorage.data();
    }
}
