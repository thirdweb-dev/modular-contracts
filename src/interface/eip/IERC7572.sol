// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

interface IERC7572 {

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when the contract URI is updated.
    event ContractURIUpdated();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Returns the contract URI of the contract.
    function contractURI() external view returns (string memory);
}