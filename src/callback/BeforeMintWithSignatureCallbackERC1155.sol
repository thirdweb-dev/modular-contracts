// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract BeforeMintWithSignatureCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BeforeMintWithSignatureCallbackERC1155NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMintWithSignatureERC1155 hook that is called by a core token before minting tokens.
     *
     *  @param _to The address that is minting tokens.
     *  @param _id The token ID being minted.
     *  @param _amount The quantity of tokens to mint.
     *  @param _data Optional extra data passed to the hook.
     *  @param _signer The address that signed the minting request.
     *  @return result Abi encoded bytes result of the hook.
     */
    function beforeMintWithSignatureERC1155(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data,
        address _signer
    ) external payable virtual returns (bytes memory result) {
        revert BeforeMintWithSignatureCallbackERC1155NotImplemented();
    }

}
