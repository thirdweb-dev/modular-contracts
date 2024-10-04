// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Core} from "../Core.sol";

import {IERC20} from "../interface/IERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

contract SplitWallet is Ownable {

    address public immutable splitFees;

    constructor(address _owner) {
        splitFees = msg.sender;
        _initializeOwner(_owner);
    }

    error OnlySplitFees();

    modifier onlySplitFees() {
        if (msg.sender != splitFees) {
            revert OnlySplitFees();
        }
        _;
    }

    function transferETH(uint256 amount) external payable onlySplitFees {
        (bool success,) = splitFees.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function transferERC20(address token, uint256 amount) external onlySplitFees {
        IERC20(token).transfer(splitFees, amount);
    }

}
