// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Core} from "../Core.sol";

contract MintFeeManagerCore is Core {

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](0);
    }

}
