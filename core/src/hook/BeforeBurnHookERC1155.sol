// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBurnHookERC1155 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeBurnERC1155 hook.
    uint256 public constant BEFORE_BURN_ERC1155_FLAG = 2 ** 7;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBurnHookERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBurnERC1155 hook that is called by a core token before burning a token.
     *  @param _operator The address that is burning tokens.
     *  @param _id The token ID being burned.
     *  @param _value The quantity of tokens being burned.
     *  @param _data The encoded arguments for the beforeBurn hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBurnERC1155(address _operator, uint256 _id, uint256 _value, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeBurnHookERC1155NotImplemented();
    }
}
