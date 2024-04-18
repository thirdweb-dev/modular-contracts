// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionTypes} from "./IExtensionTypes.sol";

interface ICoreContract is IExtensionTypes {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CallbackFunction {
        uint256 callbackFunctionBitflag;
        string callbackFunctionSignature;
        address extensionContractImplementation;
    }

    struct InstalledExtension {
        address extensionContract;
        ExtensionFunction[] extensionABI;
        uint256 implementedCallbackFunctionsBitmask;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSupportedCallbackFunctionsBitmask() external view returns (uint256);
    function getSupportedCallbackFunctions() external view returns (CallbackFunction[] memory);
    function getInstalledExtensions() external view returns (InstalledExtension[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installExtension(address _extensionContract, uint256 _value, bytes calldata _data) external;
    function uninstallExtension(address _extensionContract, uint256 _value, bytes calldata _data) external;
}
