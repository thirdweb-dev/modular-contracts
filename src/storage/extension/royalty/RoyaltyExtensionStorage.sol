// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRoyaltyInfo} from "../../../interface/common/IRoyaltyInfo.sol";

library RoyaltyExtensionStorage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("royalty.extension.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ROYALTY_EXTENSION_STORAGE_POSITION =
        0x7ee93e57dcce937c8a9b57c763d236ae026d58f90462880b3a87d31ffacf4800;

    struct Data {
        /// @notice Mapping from token => default royalty info.
        mapping(address => IRoyaltyInfo.RoyaltyInfo) defaultRoyaltyInfo;
        /// @notice Mapping from token => tokenId => royalty info.
        mapping(address => mapping(uint256 => IRoyaltyInfo.RoyaltyInfo)) royaltyInfoForToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ROYALTY_EXTENSION_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
