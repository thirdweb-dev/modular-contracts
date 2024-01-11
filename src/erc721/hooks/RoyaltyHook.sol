// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "../../interface/eip/IERC2981.sol";
import "../../interface/extension/IPermission.sol";

contract RoyaltyHook is IERC2981 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

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

    event DefaultRoyaltyUpdate(address indexed token, address indexed recipient, uint256 bps);
    event TokenRoyaltyUpdate(address indexed token, uint256 indexed tokenId, address indexed recipient, uint256 bps);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => RoyaltyInfo) private _defaultRoyaltyInfo;
    mapping(address => mapping(uint256 => RoyaltyInfo)) private _royaltyInfoForToken;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function getRoyaltyInfoForToken(address _token, uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = _royaltyInfoForToken[_token][_tokenId];
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];

        return royaltyForToken.recipient == address(0)
            ? (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps))
            : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    function getDefaultRoyaltyInfo(address _token) external view returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) external onlyAdmin(_token) {
        _setupDefaultRoyaltyInfo(_token, _royaltyRecipient, _royaltyBps);
    }

    function setRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps)
        external
        onlyAdmin(_token)
    {

        _setupRoyaltyInfoForToken(_token, _tokenId, _recipient, _bps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) internal {
        if (_royaltyBps > 10_000) {
            revert("Exceeds max bps");
        }

        _defaultRoyaltyInfo[_token] = RoyaltyInfo({recipient: _royaltyRecipient, bps: _royaltyBps});

        emit DefaultRoyaltyUpdate(_token, _royaltyRecipient, _royaltyBps);
    }

    function _setupRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps) internal {
        if (_bps > 10_000) {
            revert("Exceeds max bps");
        }

        _royaltyInfoForToken[_token][_tokenId] = RoyaltyInfo({recipient: _recipient, bps: _bps});

        emit TokenRoyaltyUpdate(_token, _tokenId, _recipient, _bps);
    }
}
