// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library SimpleMetadataStorage {
    /// @custom:storage-location erc7201:simple.metadata.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("simple.metadata.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant SIMPLE_METADATA_STORAGE_POSITION =
        0x8ec6ff141fffd07767dee37f0023e9d3be86f52ffb0ca9c1e2ac0369422b1900;

    struct Data {
        /// @notice Mapping from token => base URI
        mapping(address => mapping(uint256 => string)) uris;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SIMPLE_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
