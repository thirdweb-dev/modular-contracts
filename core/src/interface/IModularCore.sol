// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionConfig} from "./IExtensionConfig.sol";
import {IERC165} from "./IERC165.sol";

interface IModularCore is IExtensionConfig, IERC165 {
    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSupportedCallbackFunctions() external pure returns (SupportedCallbackFunction[] memory);

    function getInstalledExtensions() external view returns (InstalledExtension[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installExtension(address _extensionContract, bytes calldata _data) external payable;

    function uninstallExtension(address _extensionContract, bytes calldata _data) external payable;
}
