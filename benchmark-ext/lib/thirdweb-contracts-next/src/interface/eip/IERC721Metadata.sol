// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC721Metadata {
    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token collection.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token collection.
    function symbol() external view returns (string memory);

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @param id The token ID to fetch metadata for.
     */
    function tokenURI(uint256 id) external view returns (string memory metadata);
}
