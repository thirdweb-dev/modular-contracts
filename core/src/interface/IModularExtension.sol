// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionConfig} from "./IExtensionConfig.sol";

interface IModularExtension is IExtensionConfig {
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns all extension functions and supported callback functions of an extension contract.
     */
    function getExtensionConfig() external pure returns (ExtensionConfig memory);
}
