// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract MockMintFeeManager {

    function calculatePlatformFeeAndRecipient(uint256 _price) external view returns (uint256, address) {
        return ((_price * 100) / 10_000, address(0x3));
    }

    function getPlatformFeeReceipient() external view returns (address) {
        return address(0x3);
    }

    function getPrimarySaleAndPlatformFeeAmount(uint256 _price) external view returns (uint256, uint256) {
        uint256 platformFeeAmount = (_price * 100) / 10_000;
        uint256 primarySaleAmount = _price - platformFeeAmount;
        return (primarySaleAmount, platformFeeAmount);
    }

}
