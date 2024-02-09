// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AllowlistMintExtensionERC721} from "../../../extension/mint/AllowlistMintExtensionERC721.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library AllowlistMintExtensionERC721Storage {
    /// @custom:storage-location erc7201:permissions.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("allowlist.mint.extension.erc721.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant ALLOWLIST_MINT_EXTENSION_ERC721_STORAGE_POSITION =
        0xd230f7da7990fb90d9d6a9ddcbc1c67100b8d16fc023d14d1ab086422c8af700;

    struct Data {
        /// @notice Mapping from token => the next token ID to mint.
        mapping(address => uint256) nextTokenIdToMint;
        /// @notice Mapping from token => the claim conditions for minting the token.
        mapping(address => AllowlistMintExtensionERC721.ClaimCondition) claimCondition;
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
