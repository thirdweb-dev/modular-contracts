// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import {IERC2981} from "../../interface/eip/IERC2981.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import { TokenHook } from "../../extension/TokenHook.sol";

contract RoyaltyHook is IERC2981, TokenHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The royalty info for a token.
     *  @param recipient The royalty recipient address.
     *  @param bps The basis points of the sale price that is taken as royalty.
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

    /// @notice Emitted when the royalty info for a specific NFT of a token collection is updated.
    event TokenRoyaltyUpdate(address indexed token, uint256 indexed tokenId, address indexed recipient, uint256 bps);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => default royalty info.
    mapping(address => RoyaltyInfo) private _defaultRoyaltyInfo;

    /// @notice Mapping from token => tokenId => royalty info.
    mapping(address => mapping(uint256 => RoyaltyInfo)) private _royaltyInfoForToken;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = ROYALTY_FLAG;
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
        RoyaltyInfo memory royaltyForToken = _royaltyInfoForToken[_token][_tokenId];
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];

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
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the default royalty info for a given token.
     *  @param _token The token address.
     *  @param _royaltyRecipient The royalty recipient address.
     *  @param _royaltyBps The basis points of the sale price that is taken as royalty.
     */
    function setDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) external onlyAdmin(_token) {
        _setupDefaultRoyaltyInfo(_token, _royaltyRecipient, _royaltyBps);
    }

    /**
     *  @notice Sets the royalty info for a specific NFT of a token collection.
     *  @param _token The token address.
     *  @param _tokenId The token ID of the NFT.
     *  @param _recipient The royalty recipient address.
     *  @param _bps The basis points of the sale price that is taken as royalty.
     */
    function setRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps)
        external
        onlyAdmin(_token)
    {

        _setupRoyaltyInfoForToken(_token, _tokenId, _recipient, _bps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets the default royalty info for a given token.
    function _setupDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) internal {
        if (_royaltyBps > 10_000) {
            revert("Exceeds max bps");
        }

        _defaultRoyaltyInfo[_token] = RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdate(_token, _royaltyRecipient, _royaltyBps);
    }

    /// @dev Sets the royalty info for a specific NFT of a token collection.
    function _setupRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps) internal {
        if (_bps > 10_000) {
            revert("Exceeds max bps");
        }

        _royaltyInfoForToken[_token][_tokenId] = RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdate(_token, _tokenId, _recipient, _bps);
    }
}
