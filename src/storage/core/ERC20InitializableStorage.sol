// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC20InitializableStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc20.initializable.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC20_INITIALIZABLE_STORAGE_POSITION =
        0x69be337fbffc03995fb828152dab99b4bfa1994b151d6ae574d17e2cedb6e100;

    struct Data {
        /// @notice The name of the token.
        string name;

        /// @notice The symbol of the token.
        string symbol;

        /// @notice The total circulating supply of tokens.
        uint256 totalSupply;

        /// @notice Mapping from owner address to number of owned token.
        mapping(address => uint256) balanceOf;

        /// @notice Mapping from owner to spender allowance.
        mapping(address => mapping(address => uint256)) allowances;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC20_INITIALIZABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
