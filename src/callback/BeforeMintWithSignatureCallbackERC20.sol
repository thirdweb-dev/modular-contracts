// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract BeforeMintWithSignatureCallbackERC20 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintWithSignatureCallbackERC20NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintWithSignatureERC20 hook that is called by a core token before minting tokens.
     *
     *  @param _to The address that is minting tokens.
     *  @param _amount The amount of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @param _signer The address that signed the minting request.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintWithSignatureERC20(address _to, uint256 _amount, bytes memory _data, address _signer)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        revert BeforeMintWithSignatureCallbackERC20NotImplemented();
    }

}
