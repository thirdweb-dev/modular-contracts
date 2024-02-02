// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC721InitializableStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc721.initializable.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC721_INITIALIZABLE_STORAGE_POSITION =
        0xde736681c699ea309d8553f1fc33529507091d9d996e3146dc561047fd42da00;

    struct Data {
        /// @notice The name of the token collection.
        string name;
        /// @notice The symbol of the token collection.
        string symbol;
        /**
         *  @notice The total circulating supply of NFTs.
         *  @dev Initialized as `1` in `initialize` to save on `mint` gas.
         */
        uint256 totalSupply;
        /// @notice Mapping from token ID to TokenData i.e. owner and metadata source.
        mapping(uint256 => address) ownerOf;
        /// @notice Mapping from owner address to number of owned token.
        mapping(address => uint256) balanceOf;
        /// @notice Mapping from token ID to approved spender address.
        mapping(uint256 => address) getApproved;
        /// @notice Mapping from owner to operator approvals.
        mapping(address => mapping(address => bool)) isApprovedForAll;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC721_INITIALIZABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
