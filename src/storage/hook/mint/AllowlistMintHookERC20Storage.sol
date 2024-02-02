// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AllowlistMintHookERC20} from "../../../hook/mint/AllowlistMintHookERC20.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library AllowlistMintHookERC20Storage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("allowlist.mint.hook.erc20.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ALLOWLIST_MINT_HOOK_ERC20_STORAGE_POSITION =
        0x5717e94652118cb14f547acb0b722d99d7598b88ebdcfe02772b3b691bb2e100;

    struct Data {
        /// @notice Mapping from token => the claim conditions for minting the token.
        mapping(address => AllowlistMintHookERC20.ClaimCondition) claimCondition;

        /// @notice Mapping from token => fee config for the token.
        mapping(address => IFeeConfig.FeeConfig) feeConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ALLOWLIST_MINT_HOOK_ERC20_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
