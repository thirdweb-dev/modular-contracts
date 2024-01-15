// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IHook {

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of hooks implemented by the contract.
    function getHooksImplemented() external view returns (uint256 hooksImplemented);
}
