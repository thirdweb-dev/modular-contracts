// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {IExtensionTypes} from "./IExtensionTypes.sol";

interface ICoreContract is IExtensionTypes {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSupportedCallbackFunctions()
        external
        pure
        returns (bytes4[] memory);

    function getInstalledExtensions()
        external
        view
        returns (InstalledExtension[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installExtension(
        address _extensionContract,
        uint256 _value,
        bytes calldata _data
    ) external;

    function uninstallExtension(
        address _extensionContract,
        uint256 _value,
        bytes calldata _data
    ) external;
}
