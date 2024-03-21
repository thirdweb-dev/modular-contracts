// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ISharedMetadata} from "../interface/ISharedMetadata.sol";

library SharedMetadataStorage {
    /// @custom:storage-location erc7201:shared.metadata.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("shared.metadata.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant SHARED_METADATA_STORAGE_POSITION =
        0xfdee411af9bf3577111bd01929620c54823736ad38c2fe7a6b62d3e2d7ac0f00;

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
