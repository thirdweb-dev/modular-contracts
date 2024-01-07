// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface ITokenHook {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenHookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooksImplemented() external pure returns (uint256 hooksImplemented);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address to, bytes memory data) external payable returns (uint256 tokenIdToMint);

    function afterMint(address to, uint256 startId, uint256 _quantity) external;

    function beforeTransfer(address from, address to, uint256 tokenId) external;

    function afterTransfer(address from, address to, uint256 tokenId) external;

    function beforeBurn(address from, uint256 tokenId) external;

    function afterBurn(address from, uint256 tokenId) external;

    function beforeApprove(address from, address to, uint256 tokenId) external;

    function afterApprove(address from, address to, uint256 tokenId) external;
}