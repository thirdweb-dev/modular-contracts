// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRoyaltyInfo} from "../../../interface/common/IRoyaltyInfo.sol";

library RoyaltyHookStorage {
    /// @custom:storage-location erc7201:royalty.hook.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("royalty.hook.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ROYALTY_HOOK_STORAGE_POSITION =
        0x15ac7369311e92cebc8525c69b94ad050bd8751b6414316f40ff6d37bb3fef00;

    struct Data {
        /// @notice Mapping from token => default royalty info.
        mapping(address => IRoyaltyInfo.RoyaltyInfo) defaultRoyaltyInfo;
        /// @notice Mapping from token => tokenId => royalty info.
        mapping(address => mapping(uint256 => IRoyaltyInfo.RoyaltyInfo)) royaltyInfoForToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ROYALTY_HOOK_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
