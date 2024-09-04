// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";

import {UpdateTokenIdCallbackERC1155} from "../../../callback/UpdateTokenIdERC1155.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";

library SequentialTokenIdStorage {

    /// @custom:storage-location erc7201:token.minting.tokenId
    bytes32 public constant SEQUENTIAL_TOKEN_ID_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.tokenId.erc1155")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        uint256 nextTokenId;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SEQUENTIAL_TOKEN_ID_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract SequentialTokenIdERC1155 is Module, UpdateTokenIdCallbackERC1155 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when the tokenId is invalid.
    error SequentialTokenIdInvalidTokenId();

    /*//////////////////////////////////////////////////////////////
                                MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.updateTokenIdERC1155.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getNextTokenId.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    function updateTokenIdERC1155(uint256 _tokenId) external payable override returns (uint256) {
        uint256 _nextTokenId = _tokenIdStorage().nextTokenId;

        if (_tokenId == type(uint256).max) {
            _tokenIdStorage().nextTokenId = _nextTokenId + 1;

            return _nextTokenId;
        }

        if (_tokenId > _nextTokenId) {
            revert SequentialTokenIdInvalidTokenId();
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

    function _tokenIdStorage() internal pure returns (SequentialTokenIdStorage.Data storage) {
        return SequentialTokenIdStorage.data();
    }

}
