// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBurnCallbackERC1155 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBurnCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBurnERC1155 hook that is called by a core token before burning a token.
     *
     *  @param _from The address whose tokens are being burned.
     *  @param _id The token ID being burned.
     *  @param _value The quantity of tokens being burned.
     *  @param _data The encoded arguments for the beforeBurn hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBurnERC1155(address _from, uint256 _id, uint256 _value, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeBurnCallbackERC1155NotImplemented();
    }
}
