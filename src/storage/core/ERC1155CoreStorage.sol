// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC1155CoreStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc1155.core.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC1155_CORE_STORAGE_POSITION =
        0xda629a1eb86f9473a3f2589e2ad87835aaeee803480efaf6be871529be01d400;

    struct Data {
        /// @notice The contract URI of the contract.
        string contractURI;   
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC1155_CORE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
