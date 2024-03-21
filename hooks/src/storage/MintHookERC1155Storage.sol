// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {MintHookERC1155} from "..//token/mint/MintHookERC1155.sol";
import {IClaimCondition} from "../interface/IClaimCondition.sol";
import {IFeeConfig} from "../interface/IFeeConfig.sol";

library MintHookERC1155Storage {
    /// @custom:storage-location erc7201:mint.hook.erc1155.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("mint.hook.erc1155.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant MINT_HOOK_ERC1155_STORAGE_POSITION =
        0xf2f6808e39b972e562f3dacc9e1376d4c56d1c1177b4ec08115a630d0dc1d700;

    struct Data {
        /// @notice Mapping from token => token-id => fee config for the token.
        mapping(address => mapping(uint256 => IFeeConfig.FeeConfig)) feeConfig;
        /// @notice Mapping from token => token-id => the claim conditions for minting the token.
        mapping(address => mapping(uint256 => IClaimCondition.ClaimCondition)) claimCondition;
        /// @notice Mapping from hash(claimer, conditionID) => supply claimed by wallet.
        mapping(bytes32 => uint256) supplyClaimedByWallet;
        /// @notice Mapping from token => token-id => condition ID.
        mapping(address => mapping(uint256 => bytes32)) conditionId;
        /// @dev Mapping from permissioned mint request UID => whether the mint request is processed.
        mapping(bytes32 => bool) uidUsed;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = MINT_HOOK_ERC1155_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}
