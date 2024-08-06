// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IModuleConfig} from "./IModuleConfig.sol";

interface IModularModule is IModuleConfig {

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Returns the ModuleConfig of the Module contract.
     */
    function getModuleConfig() external pure returns (ModuleConfig memory);

}
