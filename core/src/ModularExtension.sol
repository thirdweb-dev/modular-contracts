// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IModularExtension} from "./interface/IModularExtension.sol";

abstract contract ModularExtension is IModularExtension {
    function extensionID() external pure virtual returns (string memory);

    function extensionVersion() external pure virtual returns (uint256);

    function getExtensionConfig() external pure virtual returns (ExtensionConfig memory);
}
