// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ISplitWallet {

    function transferETH(uint256 amount) external payable;
    function transferERC20(address token, uint256 amount) external;

}
