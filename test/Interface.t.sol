// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// Test utils
import {Test} from "forge-std/Test.sol";

import {IERC7572} from "src/interface/IERC7572.sol";

contract InterfaceTest is Test {
    event InterfaceId(bytes4 id);

    function testInterface() public {
        emit InterfaceId(type(IERC7572).interfaceId);
    }
}
