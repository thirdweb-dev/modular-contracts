// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

contract BeforeBurnHookERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeBurnHookERC721NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeBurnERC721 hook that is called by a core token before burning a token.
     *  @param _operator The address that is burning tokens.
     *  @param _tokenId The token ID being burned.
     *  @param _data The encoded arguments for the beforeBurn hook.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeBurnERC721(address _operator, uint256 _tokenId, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeBurnHookERC721NotImplemented();
    }
}
