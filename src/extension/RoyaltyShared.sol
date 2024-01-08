// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "../interface/extension/IRoyaltyShared.sol";

abstract contract RoyaltyShared is IRoyaltyShared {

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => RoyaltyInfo) private _defaultRoyaltyInfo;
    mapping(address => mapping(uint256 => RoyaltyInfo)) private _royaltyInfoForToken;

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view virtual override returns (address receiver, uint256 royaltyAmount) {
        address token = msg.sender;
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(token, _tokenId);
        receiver = recipient;
        royaltyAmount = (_salePrice * bps) / 10_000;
    }

    function getRoyaltyInfoForToken(address _token, uint256 _tokenId) public view override returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = _royaltyInfoForToken[_token][_tokenId];
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];

        return
            royaltyForToken.recipient == address(0)
                ? (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps))
                : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    function getDefaultRoyaltyInfo(address _token) external view override returns (address, uint16) {
        RoyaltyInfo memory defaultRoyaltyInfo = _defaultRoyaltyInfo[_token];
        return (defaultRoyaltyInfo.recipient, uint16(defaultRoyaltyInfo.bps));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) external override {
        if (!_canSetRoyaltyInfo()) {
            revert("Not authorized");
        }

        _setupDefaultRoyaltyInfo(_token, _royaltyRecipient, _royaltyBps);
    }

    function setRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps) external override {
        if (!_canSetRoyaltyInfo()) {
            revert("Not authorized");
        }

        _setupRoyaltyInfoForToken(_token, _tokenId, _recipient, _bps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupDefaultRoyaltyInfo(address _token, address _royaltyRecipient, uint256 _royaltyBps) internal {
        if (_royaltyBps > 10_000) {
            revert("Exceeds max bps");
        }

        _defaultRoyaltyInfo[_token] = RoyaltyInfo({ recipient: _royaltyRecipient, bps: _royaltyBps });

        emit DefaultRoyaltyUpdate(_token, _royaltyRecipient, _royaltyBps);
    }

    function _setupRoyaltyInfoForToken(address _token, uint256 _tokenId, address _recipient, uint256 _bps) internal {
        if (_bps > 10_000) {
            revert("Exceeds max bps");
        }

        _royaltyInfoForToken[_token][_tokenId] = RoyaltyInfo({ recipient: _recipient, bps: _bps });

        emit TokenRoyaltyUpdate(_token, _tokenId, _recipient, _bps);
    }

    function _canSetRoyaltyInfo() internal view virtual returns (bool);
}
