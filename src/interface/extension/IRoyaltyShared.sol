// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "../eip/IERC2981.sol";

interface IRoyaltyShared is IERC2981 {

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
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getDefaultRoyaltyInfo(address token) external view returns (address, uint16);

    function getRoyaltyInfoForToken(address token, uint256 tokenId) external view returns (address, uint16);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setDefaultRoyaltyInfo(address token, address _royaltyRecipient, uint256 _royaltyBps) external;

    function setRoyaltyInfoForToken(address token, uint256 tokenId, address recipient, uint256 bps) external;
}