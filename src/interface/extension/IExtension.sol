// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IExtension {
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all extensions implemented by the contract -- represented in the bits of the returned integer.
    function getExtensions() external view returns (uint256 extensionsImplemented);
}
