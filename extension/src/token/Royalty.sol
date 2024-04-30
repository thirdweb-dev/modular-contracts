// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";

library RoyaltyStorage {
    /// @custom:storage-location erc7201:royalty.storage
    bytes32 public constant ROYALTY_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("royalty.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice Mapping from token => default royalty info.
        mapping(address => Royalty.RoyaltyInfo) defaultRoyaltyInfo;
        /// @notice Mapping from token => tokenId => royalty info.
        mapping(address => mapping(uint256 => Royalty.RoyaltyInfo)) royaltyInfoForToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ROYALTY_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract Royalty is IExtensionContract {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RoyaltyInfo {
        address recipient;
        uint256 bps;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the default royalty info for a token is updated.
    event DefaultRoyaltyUpdate(address indexed token, address indexed recipient, uint256 bps);

    /// @notice Emitted when the royalty info for a specific NFT of a token collection is updated.
    event TokenRoyaltyUpdate(address indexed token, uint256 indexed tokenId, address indexed recipient, uint256 bps);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when royalty BPS exceeds 10,000.
    error RoyaltyExceedsMaxBps();

    /*//////////////////////////////////////////////////////////////
                               EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](0);
        config.extensionABI = new ExtensionFunction[](5);

        config.extensionABI[0] =
            ExtensionFunction({selector: this.royaltyInfo.selector, callType: CallType.STATICCALL, permissioned: false});
        config.extensionABI[1] = ExtensionFunction({
            selector: this.getDefaultRoyaltyInfo.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[2] = ExtensionFunction({
            selector: this.getRoyaltyInfoForToken.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[3] = ExtensionFunction({
            selector: this.setDefaultRoyaltyInfo.selector,
            callType: CallType.CALL,
            permissioned: true
        });
        config.extensionABI[4] = ExtensionFunction({
            selector: this.setRoyaltyInfoForToken.selector,
            callType: CallType.CALL,
            permissioned: true
        });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the royalty recipient and amount for a given sale.
     *  @dev Meant to be called by a token contract.
     *  @param _tokenId The token ID of the NFT.
     *  @param _salePrice The sale price of the NFT.
     *  @return receiver The royalty recipient address.
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale.
     */
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

    /**
     *  @notice Returns the overriden royalty info for a given token.
     *  @param _token The token address.
     *  @param _tokenId The token ID of the NFT.
     *  @return recipient The royalty recipient address.
     *  @return bps The basis points of the sale price that is taken as royalty.
     */
    function getRoyaltyInfoForToken(address _token, uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyStorage.Data storage data = RoyaltyStorage.data();
        RoyaltyInfo memory royaltyForToken = data.royaltyInfoForToken[_token][_tokenId];

        return (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /**
     *  @notice Returns the default royalty info for a given token.
     *  @param _token The token address.
     *  @return recipient The royalty recipient address.
     *  @return bps The basis points of the sale price that is taken as royalty.
     */
    function getDefaultRoyaltyInfo(address _token) public view returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = RoyaltyStorage.data().defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /**
     *  @notice Sets the default royalty info for a given token.
     *  @param _royaltyRecipient The royalty recipient address.
     *  @param _royaltyBps The basis points of the sale price that is taken as royalty.
     */
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps) external {
        address token = msg.sender;
        if (_royaltyBps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().defaultRoyaltyInfo[token] = RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdate(token, _royaltyRecipient, _royaltyBps);
    }

    /**
     *  @notice Sets the royalty info for a specific NFT of a token collection.
     *  @param _tokenId The token ID of the NFT.
     *  @param _recipient The royalty recipient address.
     *  @param _bps The basis points of the sale price that is taken as royalty.
     */
    function setRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint256 _bps) external {
        address token = msg.sender;
        if (_bps > 10_000) {
            revert RoyaltyExceedsMaxBps();
        }

        RoyaltyStorage.data().royaltyInfoForToken[token][_tokenId] = RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdate(token, _tokenId, _recipient, _bps);
    }
}
