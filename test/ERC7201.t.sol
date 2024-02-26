// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

contract ERC7201Test is Test {
    event StoragePos(bytes32 pos);

    function test_storagePos() public {
        bytes32 pos = keccak256(abi.encode(uint256(keccak256("simple.metadata.storage")) - 1)) &
            ~bytes32(uint256(0xff));
        emit StoragePos(pos);
    }
}
