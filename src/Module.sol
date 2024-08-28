// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IModule} from "./interface/IModule.sol";

abstract contract Module is IModule {

    function getModuleConfig() external pure virtual returns (ModuleConfig memory);

}
