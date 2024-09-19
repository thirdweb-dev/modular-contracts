// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IMintFeeManager {

    function getPlatformFeeAndRecipient(uint256 _price) external view returns (uint256, address);

}
