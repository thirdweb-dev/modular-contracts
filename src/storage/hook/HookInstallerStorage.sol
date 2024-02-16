// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "../../lib/LibBitmap.sol";

library HookInstallerStorage {
    /// @custom:storage-location erc7201:hook.installer.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("hook.installer.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant HOOK_INSTALLER_STORAGE_POSITION =
        0xd2fc9476a829f33ae1fdc9a47466a061a6e8e0cf7f5232e2241979d13a3c2a00;

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
