// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { ISharedMetadata } from "../../../interface/common/ISharedMetadata.sol";

library SharedMetadataStorage {
    /// @custom:storage-location erc7201:shared.metadata.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("shared.metadata.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant SHARED_METADATA_STORAGE_POSITION = 0x00;

    struct Data {
        /// @notice Token metadata information
        mapping(address => ISharedMetadata.SharedMetadataInfo) sharedMetadata;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SHARED_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
