// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract OnTokenURICallback {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnTokenURICallbackNotImplemented();

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
        revert OnTokenURICallbackNotImplemented();
    }
}
