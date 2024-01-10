// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

interface ITokenHook {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenHookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooksImplemented() external view returns (uint256 hooksImplemented);

    function getBeforeMintArgSignature() external view returns (string memory argSignature);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address to, uint256 quantity, bytes memory data)
        external
        payable
        returns (uint256 tokenIdToMint);

    function beforeTransfer(address from, address to, uint256 tokenId) external;

    function beforeBurn(address from, uint256 tokenId) external;

    function beforeApprove(address from, address to, uint256 tokenId) external;
}
