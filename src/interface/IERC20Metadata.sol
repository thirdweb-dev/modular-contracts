// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import "./IERC20.sol";

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

}
