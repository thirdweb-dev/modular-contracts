// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AllowlistMintHookERC1155} from "../../../hook/mint/AllowlistMintHookERC1155.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library AllowlistMintHookERC1155Storage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("allowlist.mint.hook.erc1155.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ALLOWLIST_MINT_HOOK_ERC1155_STORAGE_POSITION =
        0x6cab0ee0a8253dbae8b34a126d2ef615f750bc540a636062aaf3442af54e6e00;

    struct Data {
        /// @notice Mapping from token => token-id => the claim conditions for minting the token.
        mapping(address => mapping(uint256 => AllowlistMintHookERC1155.ClaimCondition)) claimCondition;
        /// @notice Mapping from token => token-id => fee config for the token.
        mapping(address => mapping(uint256 => IFeeConfig.FeeConfig)) feeConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ALLOWLIST_MINT_HOOK_ERC1155_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
