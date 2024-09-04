// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract UpdateTokenIdCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UpdateTokenIdCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The updateTokenIdERC1155 hook that is called by a core token before minting tokens.
     *
     *  @dev If the tokenId is type(uint256).max, the next tokenId will be set to the current next tokenId + amount.
     *
     *  @param _tokenId The tokenId to mint.
     *  @param _amount The amount of tokens to mint.
     *  @return result tokenId to mint.
     */
    function updateTokenIdERC1155(uint256 _tokenId, uint256 _amount) external payable virtual returns (uint256) {
        revert UpdateTokenIdCallbackERC1155NotImplemented();
    }

}
