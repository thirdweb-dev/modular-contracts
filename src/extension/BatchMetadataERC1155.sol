// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {BatchMetadataERC721} from "./BatchMetadataERC721.sol";

contract BatchMetadataERC1155 is BatchMetadataERC721 {
    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure virtual override returns (ExtensionConfig memory config) {
        config = super.getExtensionConfig();
        config.requiredInterfaceId = 0xd9b67a26; // ERC1155
    }
}
