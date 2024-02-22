// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC721Supply {
    /**
     *  @notice Returns the total circulating supply of NFTs.
     *  @return supply The total circulating supply of NFTs
     */
    function totalSupply() external view returns (uint256 supply);
}
