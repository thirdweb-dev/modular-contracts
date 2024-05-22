// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IERC721Burnable {
    function burn(uint256 tokenId) external;
}

interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IERC1155Burnable {
    function burn(address account, uint256 id, uint256 value) external;
}

library BurnAndMintStorage {
    /// @custom:storage-location erc7201:burn.and.mint.storage
    bytes32 public constant BURN_AND_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("burn.and.mint.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token address => sale config: primary sale recipient, and platform fee recipient + BPS.
        mapping(address => BurnAndMintERC721.SaleConfig) saleConfig;
        // token address => burn and mint conditions
        mapping(address => BurnAndMintERC721.BurnAndMintConditions) conditions;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BURN_AND_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract BurnAndMintERC721 is ModularExtension {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice The type of assets that can be burned.
    enum TokenType {
        ERC721,
        ERC1155
    }

    struct BurnAndMintConditions {
        address originContractAddress;
        TokenType tokenType;
        uint256 tokenId; // used only if tokenType is ERC1155
        uint256 mintPriceForNewToken;
        address currency;
    }

    struct BurnAndMintParams {
        uint256 burnTokenId;
    }

    /**
     *  @notice Details for distributing the proceeds of a mint.
     *  @param primarySaleRecipient The address to which the total proceeds minus fees are sent.
     *  @param platformFeeRecipient The address to which the platform fee is sent.
     *  @param platformFeeBps The platform fee in basis points. 10_000 BPS = 100%.
     */
    struct SaleConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when incorrect amount of native token is sent.
    error BurnAndMintIncorrectNativeTokenSent();

    error BurnAndMintInvalidQuantity();

    error BurnAndMintNotEnoughBalance();

    error BurnAndMintNotOwner();

    error BurnAndMintInvalidTokenId();

    error BurnAndMintInvalidOrigin();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are burned to claim new tokens
    event TokensBurnedAndClaimed(
        address indexed originContract, address indexed tokenOwner, uint256 indexed burnTokenId, uint256 quantity
    );

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[1] = CallbackFunction(this.beforeMintERC721.selector, CallType.CALL);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.getSaleConfig.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getBurnAndMintConditions.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setBurnAndMintConditions.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });

        config.requiredInterfaceId = 0x80ac58cd; // ERC721
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(address _caller, address, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        BurnAndMintParams memory _params = abi.decode(_data, (BurnAndMintParams));
        _burnAndMint(_caller, _quantity, _params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getBurnAndMintConditions(address _token) public view returns (BurnAndMintConditions memory) {
        BurnAndMintConditions memory _conditions = _burnAndMintStorage().conditions[_token];

        return _conditions;
    }

    function setBurnAndMintConditions(BurnAndMintConditions calldata _conditions) public virtual {
        address token = msg.sender;

        if (_conditions.originContractAddress == address(0)) {
            revert BurnAndMintInvalidOrigin();
        }

        _burnAndMintStorage().conditions[token] = _conditions;
    }

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _burnAndMintStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _burnAndMintStorage().saleConfig[token] =
            SaleConfig(_primarySaleRecipient, _platformFeeRecipient, _platformFeeBps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint new tokens after burning required tokens from origin contract.
    function _burnAndMint(address _tokenOwner, uint256 _quantity, BurnAndMintParams memory _params) internal {
        BurnAndMintConditions memory _conditions = _burnAndMintStorage().conditions[msg.sender];

        // Verify and burn tokens on origin contract
        _verifyBurnAndMint(_tokenOwner, _params.burnTokenId, _quantity, _conditions);
        _burnTokensOnOrigin(_tokenOwner, _params.burnTokenId, _quantity, _conditions);

        // Collect price
        if (_conditions.currency != address(0)) {
            _distributeMintPrice(_tokenOwner, _conditions.currency, _quantity * _conditions.mintPriceForNewToken);
        }

        // emit event
        emit TokensBurnedAndClaimed(_conditions.originContractAddress, _tokenOwner, _params.burnTokenId, _quantity);
    }

    function _verifyBurnAndMint(
        address _tokenOwner,
        uint256 _tokenId,
        uint256 _quantity,
        BurnAndMintConditions memory _conditions
    ) public view virtual {
        if (_conditions.tokenType == TokenType.ERC721) {
            if (_quantity != 1) {
                revert BurnAndMintInvalidQuantity();
            }
            if (IERC721(_conditions.originContractAddress).ownerOf(_tokenId) != _tokenOwner) {
                revert BurnAndMintNotOwner();
            }
        } else if (_conditions.tokenType == TokenType.ERC1155) {
            uint256 _eligible1155TokenId = _conditions.tokenId;

            if (_tokenId != _eligible1155TokenId) {
                revert BurnAndMintInvalidTokenId();
            }

            if (IERC1155(_conditions.originContractAddress).balanceOf(_tokenOwner, _tokenId) < _quantity) {
                revert BurnAndMintNotEnoughBalance();
            }
        }
    }

    function _burnTokensOnOrigin(
        address _tokenOwner,
        uint256 _tokenId,
        uint256 _quantity,
        BurnAndMintConditions memory _conditions
    ) internal virtual {
        if (_conditions.tokenType == TokenType.ERC721) {
            IERC721Burnable(_conditions.originContractAddress).burn(_tokenId);
        } else if (_conditions.tokenType == TokenType.ERC1155) {
            IERC1155Burnable(_conditions.originContractAddress).burn(_tokenOwner, _tokenId, _quantity);
        }
    }

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert BurnAndMintIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _burnAndMintStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert BurnAndMintIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    function _burnAndMintStorage() internal pure returns (BurnAndMintStorage.Data storage) {
        return BurnAndMintStorage.data();
    }
}
