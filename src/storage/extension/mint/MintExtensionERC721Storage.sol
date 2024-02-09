// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {MintExtensionERC721} from "../../../extension/mint/MintExtensionERC721.sol";
import {IClaimCondition} from "../../../interface/common/IClaimCondition.sol";
import {IFeeConfig} from "../../../interface/common/IFeeConfig.sol";

library MintExtensionERC721Storage {
    /// @custom:storage-location erc7201:mint.extension.erc721.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("mint.extension.erc721.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant MINT_EXTENSION_ERC721_STORAGE_POSITION =
        0x83e4a22132ea4bd561adebc5dd1863248e590f261adf89d5daf7fc27a8a37200;

    struct Data {
        /// @notice Mapping from token => the next token ID to mint.
        mapping(address => uint256) nextTokenIdToMint;
        /// @notice Mapping from token => token-id => fee config for the token.
        mapping(address => mapping(uint256 => IFeeConfig.FeeConfig)) feeConfig;
        /// @notice Mapping from token => the claim conditions for minting the token.
        mapping(address => IClaimCondition.ClaimCondition) claimCondition;
        /// @notice Mapping from hash(claimer, conditionID) => supply claimed by wallet.
        mapping(bytes32 => uint256) supplyClaimedByWallet;
        /// @notice Mapping from token => condition ID.
        mapping(address => bytes32) conditionId;
        /// @dev Mapping from permissioned mint request UID => whether the mint request is processed.
        mapping(bytes32 => bool) uidUsed;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = MINT_EXTENSION_ERC721_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
