// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";

import {UpdateTokenIdCallbackERC1155} from "../../../callback/UpdateTokenIdERC1155.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";

library TokenIdStorage {

    /// @custom:storage-location erc7201:token.minting.tokenId
    bytes32 public constant TOKEN_ID_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.tokenId.erc1155")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        uint256 nextTokenId;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = TOKEN_ID_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract TokenIdERC1155 is Module, UpdateTokenIdCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when the tokenId is invalid.
    error TokenIdInvalidTokenId();

    /*//////////////////////////////////////////////////////////////
                                MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.updateTokenId.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getNextTokenId.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    function updateTokenId(uint256 _tokenId, uint256 _amount) external returns (uint256) {
        uint256 _nextTokenId = _tokenIdStorage().nextTokenId;

        if (_tokenId == type(uint256).max) {
            _tokenIdStorage().nextTokenId = _nextTokenId + _amount;

            return _nextTokenId;
        }

        if (_tokenId >= _nextTokenId) {
            revert TokenIdInvalidTokenId();
        }

        return _tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdStorage().nextTokenId;
    }

    function _tokenIdStorage() internal pure returns (TokenIdStorage.Data storage) {
        return TokenIdStorage.data();
    }

}
