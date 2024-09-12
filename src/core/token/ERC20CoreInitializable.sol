// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20Base} from "./ERC20Base.sol";
import {Initializable} from "@solady/utils/Initializable.sol";

contract ERC20CoreInitializable is ERC20Base, Initializable {

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _owner,
        address[] memory _modules,
        bytes[] memory _moduleInstallData
    ) external payable initializer {
        _initialize(_name, _symbol, _contractURI, _owner, _modules, _moduleInstallData);
    }

}
