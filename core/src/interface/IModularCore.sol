// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IModular} from "./IModular.sol";

interface IModularCore is IModular {
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
        bool permission;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSupportedCallbackFunctions()
        external
        pure
        returns (SupportedCallbackFunction[] memory);

    function getInstalledExtensions()
        external
        view
        returns (InstalledExtension[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installExtension(address _extensionContract, bytes calldata _data)
        external
        payable;

    function uninstallExtension(
        address _extensionContract,
        bytes calldata _data
    ) external payable;
}
