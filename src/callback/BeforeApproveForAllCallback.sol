// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeApproveForAllCallback {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeApproveForAllCallbackNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeApproveForAll hook that is called by a core token before approving an operator to transfer all tokens.
     *  @param _caller The address of the caller.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _approved Whether to grant or revoke approval.
     */
    function beforeApproveForAll(address _caller, address _from, address _to, bool _approved)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeApproveForAllCallbackNotImplemented();
    }
}
