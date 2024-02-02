// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library ERC20CoreStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("erc20.core.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ERC20_CORE_STORAGE_POSITION =
        0x320b967284055cc7ad7985bbfa571b80c857ec15c99052440d4076d73b084500;

    struct Data {
        /// @notice The contract URI of the contract.
        string contractURI;

        /// @notice nonces for EIP-2612 Permit functionality.
        mapping(address => uint256) nonces;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ERC20_CORE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
