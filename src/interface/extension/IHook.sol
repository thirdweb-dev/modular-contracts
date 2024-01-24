// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IHook {

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hooks implemented by the contract -- represented in the bits of the returned integer.
    function getHooks() external view returns (uint256 hooksImplemented);
}
