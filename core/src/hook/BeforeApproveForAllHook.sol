// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeApproveForAllHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeApproveForAll hook.
    uint256 public constant BEFORE_APPROVE_FOR_ALL_FLAG = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeApproveForAllHookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeApproveForAll hook that is called by a core token before approving an operator to transfer all tokens.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _approved Whether to grant or revoke approval.
     */
    function beforeApproveForAll(address _from, address _to, bool _approved)
        external
        virtual
        returns (bytes memory result)
    {
        revert BeforeApproveForAllHookNotImplemented();
    }
}
