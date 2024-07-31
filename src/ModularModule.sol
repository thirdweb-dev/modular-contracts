// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IModularModule} from "./interface/IModularModule.sol";

abstract contract ModularModule is IModularModule {

    function getModuleConfig() external pure virtual returns (ModuleConfig memory);

}
