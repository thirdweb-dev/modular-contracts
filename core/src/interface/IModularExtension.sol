// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionConfig} from "./IExtensionConfig.sol";

interface IModularExtension is IExtensionConfig {
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Returns the ExtensionConfig of the Extension contract.
     */
    function getExtensionConfig() external pure returns (ExtensionConfig memory);
}
