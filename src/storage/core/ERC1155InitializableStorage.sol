// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC1155InitializableStorage {
    /// @custom:storage-location erc7201:erc1155.initializable.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc1155.initializable.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC1155_INITIALIZABLE_STORAGE_POSITION =
        0xc1d6831519e25efab92de561ba77a4fcc047b76be43d4e7ea1eef649887f3500;

    struct Data {
        /// @notice The name of the token collection.
        string name;
        /// @notice The symbol of the token collection.
        string symbol;
        /**
         *  @notice Token ID => total circulating supply of tokens with that ID.
         */
        mapping(uint256 => uint256) totalSupply;
        /// @notice Mapping from owner address to ID to amount of owned tokens with that ID.
        mapping(address => mapping(uint256 => uint256)) balanceOf;
        /// @notice Mapping from owner to operator approvals.
        mapping(address => mapping(address => bool)) isApprovedForAll;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC1155_INITIALIZABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
