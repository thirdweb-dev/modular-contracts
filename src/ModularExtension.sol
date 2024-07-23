// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IModularExtension} from "./interface/IModularExtension.sol";

abstract contract ModularExtension is IModularExtension {

    function getExtensionConfig() external pure virtual returns (ExtensionConfig memory);

}
