// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "../../lib/LibBitmap.sol";

library ExtensionInstallerStorage {
    /// @custom:storage-location erc7201:extension.installer.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("extension.installer.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant EXTENSION_INSTALLER_STORAGE_POSITION =
        0x1f92fde37cbc580c6ce7e24a47f7ccbddcf380202caa25a340ea884cf71d9600;

    struct Data {
        /// @notice Bits representing all extensions installed.
        uint256 installedExtensions;
        /// @notice Whether a given extension is installed in the contract.
        LibBitmap.Bitmap extensionImplementations;
        /// @notice Mapping from extension bits representation => implementation of the extension.
        mapping(uint256 => address) extensionImplementationMap;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = EXTENSION_INSTALLER_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
