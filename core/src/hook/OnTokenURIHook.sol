// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

abstract contract OnTokenURIHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the onTokenURI hook.
    uint256 public constant ON_TOKEN_URI_FLAG = 2 ** 15;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnTokenURIHookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch token metadata from.
     */
    function onTokenURI(uint256 _tokenId) external view virtual returns (string memory metadata) {
        revert OnTokenURIHookNotImplemented();
    }
}
