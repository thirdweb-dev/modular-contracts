// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC721CoreStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc721.core.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC721_CORE_STORAGE_POSITION =
        0xa6a5e5e300f9d3ac9405142360702196b4ea62114d51fa073601cc0874436a00;

    struct Data {
        /// @notice The contract URI of the contract.
        string contractURI;   
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC721_CORE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
