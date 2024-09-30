// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Core} from "../Core.sol";

import {Initializable} from "@solady/utils/Initializable.sol";

contract MintFeeManagerCore is Core, Initializable {

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
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
