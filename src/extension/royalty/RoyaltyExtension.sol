// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import {IPermission} from "../../interface/common/IPermission.sol";
import {IRoyaltyInfo} from "../../interface/common/IRoyaltyInfo.sol";
import {ERC1155Extension} from "../ERC1155Extension.sol";

import {RoyaltyExtensionStorage} from "../../storage/extension/royalty/RoyaltyExtensionStorage.sol";

contract RoyaltyExtension is IRoyaltyInfo, ERC1155Extension {
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

    /// @notice Emitted when caller is not token core admin.
    error RoyaltyExtensionNotAuthorized();

    /// @notice Emitted when royalty BPS exceeds 10,000.
    error RoyaltyExtensionExceedsMaxBps();

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC1155Extension_init(_upgradeAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all extension functions implemented by this extension contract.
    function getExtensions() external pure returns (uint256 extensionsImplemented) {
        extensionsImplemented = ROYALTY_INFO_FLAG();
    }

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
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        address token = msg.sender;
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(token, _tokenId);
        receiver = recipient;
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
        RoyaltyExtensionStorage.Data storage data = RoyaltyExtensionStorage.data();

        RoyaltyInfo memory royaltyForToken = data.royaltyInfoForToken[_token][_tokenId];
        RoyaltyInfo memory defaultRoyaltyInfo = data.defaultRoyaltyInfo[_token];

        return royaltyForToken.recipient == address(0)
            ? (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps))
            : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /**
     *  @notice Returns the default royalty info for a given token.
     *  @param _token The token address.
     *  @return recipient The royalty recipient address.
     *  @return bps The basis points of the sale price that is taken as royalty.
     */
    function getDefaultRoyaltyInfo(address _token) external view returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = RoyaltyExtensionStorage.data().defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the default royalty info for a given token.
     *  @param _royaltyRecipient The royalty recipient address.
     *  @param _royaltyBps The basis points of the sale price that is taken as royalty.
     */
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps)
        external
    {
        address token = msg.sender;
        if (_royaltyBps > 10_000) {
            revert RoyaltyExtensionExceedsMaxBps();
        }

        RoyaltyExtensionStorage.data().defaultRoyaltyInfo[token] =
            RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdate(token, _royaltyRecipient, _royaltyBps);
    }

    /**
     *  @notice Sets the royalty info for a specific NFT of a token collection.
     *  @param _tokenId The token ID of the NFT.
     *  @param _recipient The royalty recipient address.
     *  @param _bps The basis points of the sale price that is taken as royalty.
     */
    function setRoyaltyInfoForToken(uint256 _tokenId, address _recipient, uint256 _bps)
        external
    {
        address token = msg.sender;
        if (_bps > 10_000) {
            revert RoyaltyExtensionExceedsMaxBps();
        }

        RoyaltyExtensionStorage.data().royaltyInfoForToken[token][_tokenId] =
            RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdate(token, _tokenId, _recipient, _bps);
    }
}
