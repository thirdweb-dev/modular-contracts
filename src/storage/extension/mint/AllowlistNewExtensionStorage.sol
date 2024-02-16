// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AllowlistNewExtension} from "../../../extension/mint/AllowlistNewExtension.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library AllowlistNewExtensionStorage {
    /// @custom:storage-location erc7201:allowlist.mint.extension.erc721.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("allowlist.mint.extension.erc721.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ALLOWLIST_MINT_EXTENSION_ERC721_STORAGE_POSITION =
        0xd9a50cc3f63a428d8d0ac630e092669535f7dbcc2bcb19dbfeea0738562b3e00;

    struct Data {
        /// @notice Mapping from token => the next token ID to mint.
        mapping(address => uint256) nextTokenIdToMint;
        /// @notice Mapping from token => the claim conditions for minting the token.
        mapping(address => AllowlistNewExtension.ClaimCondition) claimCondition;
        /// @notice Mapping from token => token-id => fee config for the token.
        mapping(address => mapping(uint256 => IFeeConfig.FeeConfig)) feeConfig;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ALLOWLIST_MINT_EXTENSION_ERC721_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
