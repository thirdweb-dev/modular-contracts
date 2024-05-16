// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../ModularExtension.sol";

library RoyaltyStorage {
    /// @custom:storage-location erc7201:royalty.storage
    bytes32 public constant ROYALTY_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("royalty.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice token => default royalty info
        mapping(address => RoyaltyERC721.RoyaltyInfo) defaultRoyaltyInfo;
        /// @notice token => tokenId => royalty info
        mapping(address => mapping(uint256 => RoyaltyERC721.RoyaltyInfo)) royaltyInfoForToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ROYALTY_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract RoyaltyERC721 is ModularExtension {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *   @notice RoyaltyInfo struct to store royalty information.
     *   @param recipient The address that will receive the royalty payment.
     *   @param bps The percentage of a secondary sale that will be paid as royalty.
     */
    struct RoyaltyInfo {
        address recipient;
        uint256 bps;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the default royalty info for a token is updated.
    event DefaultRoyaltyUpdate(address indexed token, address indexed recipient, uint256 bps);

    /// @notice Emitted when the royalty info for a specific NFT is updated.
    event TokenRoyaltyUpdate(address indexed token, uint256 indexed tokenId, address indexed recipient, uint256 bps);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when royalty BPS exceeds 10,000.
    error RoyaltyExceedsMaxBps();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                               EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](0);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.royaltyInfo.selector, callType: CallType.STATICCALL, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.getDefaultRoyaltyInfo.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getRoyaltyInfoForToken.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setDefaultRoyaltyInfo.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[4] = FallbackFunction({
            selector: this.setRoyaltyInfoForToken.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });

        config.requiredInterfaceId = 0x80ac58cd; // ERC721.

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x2a55205a; // IERC2981.
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the royalty recipient and amount for a given sale.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        address token = msg.sender;

        (address overrideRecipient, uint16 overrideBps) = getRoyaltyInfoForToken(token, _tokenId);
        (address defaultRecipient, uint16 defaultBps) = getDefaultRoyaltyInfo(token);

        receiver = overrideRecipient == address(0) ? defaultRecipient : overrideRecipient;

        uint16 bps = overrideBps == 0 ? defaultBps : overrideBps;
        royaltyAmount = (_salePrice * bps) / 10_000;
    }

    /// @notice Returns the overriden royalty info for a given token.
    function getRoyaltyInfoForToken(address _token, uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyStorage.Data storage data = RoyaltyStorage.data();
        RoyaltyInfo memory royaltyForToken = data.royaltyInfoForToken[_token][_tokenId];

        return (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /// @notice Returns the default royalty info for a given token.
    function getDefaultRoyaltyInfo(address _token) public view returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = RoyaltyStorage.data().defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /// @notice Sets the default royalty info for a given token.
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps) external {
        address token = msg.sender;
        if (_royaltyBps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().defaultRoyaltyInfo[token] = RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdate(token, _royaltyRecipient, _royaltyBps);
    }

    /// @notice Sets the royalty info for a specific NFT of a token collection.
    function setRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint256 _bps) external {
        address token = msg.sender;
        if (_bps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().royaltyInfoForToken[token][_tokenId] = RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdate(token, _tokenId, _recipient, _bps);
    }
}
