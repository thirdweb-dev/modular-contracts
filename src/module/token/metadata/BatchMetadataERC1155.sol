// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Role} from "../../../Role.sol";

import {UpdateMetadataCallbackERC1155} from "../../../callback/UpdateMetadataCallbackERC1155.sol";
import {BatchMetadataERC721} from "./BatchMetadataERC721.sol";

contract BatchMetadataERC1155 is BatchMetadataERC721, UpdateMetadataCallbackERC1155 {

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](6);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.callbackFunctions[1] = CallbackFunction(this.updateMetadataERC1155.selector);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.uploadMetadata.selector, permissionBits: Role._MINTER_ROLE});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setBaseURI.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.getAllMetadataBatches.selector, permissionBits: 0});
        config.fallbackFunctions[3] = FallbackFunction({selector: this.getMetadataBatch.selector, permissionBits: 0});
        config.fallbackFunctions[4] = FallbackFunction({selector: this.nextTokenIdToMint.selector, permissionBits: 0});
        config.fallbackFunctions[5] = FallbackFunction({selector: this.getBatchIndex.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

    /// @notice Callback function for updating metadata
    function updateMetadataERC1155(address _to, uint256 _startTokenId, uint256 _quantity, string calldata _baseURI)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        if (_startTokenId < _batchMetadataStorage().nextTokenIdRangeStart) {
            revert BatchMetadataMetadataAlreadySet();
        }
        _setMetadata(_startTokenId, _quantity, _baseURI);
    }

}
