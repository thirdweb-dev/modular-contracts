// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token collection.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token collection.
    function symbol() external view returns (string memory);

    /// @notice Returns the number of decimals used to get its user representation.
    function decimals() external view returns (uint8);
}
