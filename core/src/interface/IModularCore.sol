// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionConfig} from "./IExtensionConfig.sol";
import {IERC165} from "./IERC165.sol";

interface IModularCore is IExtensionConfig, IERC165 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    struct InstalledExtensionFunction {
        address implementation;
        CallType callType;
        uint256 permissionBits;
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
