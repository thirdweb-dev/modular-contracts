// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

interface IERC721Metadata {

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 id) external view returns (string memory metadata);
}