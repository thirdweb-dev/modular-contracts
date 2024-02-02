// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library LazyMintStorage {
    /// @custom:storage-location erc7201:lazymint.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("lazymint.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant LAZY_MINT_STORAGE_POSITION =
        0x8911971c3aad928c9cac140eac0269f3210708ac8d69db5b5f5c70209d935800;

    struct Data {
        /// @notice Mapping from token => batch IDs
        mapping(address => uint256[]) batchIds;

        /// @notice Mapping from token => the next token ID to lazy mint.
        mapping(address => uint256) nextTokenIdToLazyMint;

        /// @notice Mapping from token => batchId => baseURI
        mapping(address => mapping(uint256 => string)) baseURI;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = LAZY_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
