// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AllowlistMintExtensionERC20} from "../../../extension/mint/AllowlistMintExtensionERC20.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library AllowlistMintExtensionERC20Storage {
    /// @custom:storage-location erc7201:allowlist.mint.extension.erc20.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("allowlist.mint.extension.erc20.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ALLOWLIST_MINT_EXTENSION_ERC20_STORAGE_POSITION =
        0x336f58a6f0e0b2c18051f4f629470fae139805913a4eb1c7ab13511dbc867100;

    struct Data {
        /// @notice Mapping from token => the claim conditions for minting the token.
        mapping(address => AllowlistMintExtensionERC20.ClaimCondition) claimCondition;
        /// @notice Mapping from token => fee config for the token.
        mapping(address => IFeeConfig.FeeConfig) feeConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ALLOWLIST_MINT_EXTENSION_ERC20_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
