// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { LibBitmap } from "@solady/utils/LibBitmap.sol";

library HookInstallerStorage {
    /// @custom:storage-location erc7201:hook.installer.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("hook.installer.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant HOOK_INSTALLER_STORAGE_POSITION =
        0x1f92fde37cbc580c6ce7e24a47f7ccbddcf380202caa25a340ea884cf71d9600;

    struct Data {
        /// @notice Bits representing all hooks installed.
        uint256 installedHooks;
        /// @notice Whether a given hook is installed in the contract.
        LibBitmap.Bitmap hookImplementations;
        /// @notice Mapping from hook bits representation => implementation of the hook.
        mapping(uint256 => address) hookImplementationMap;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = HOOK_INSTALLER_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
