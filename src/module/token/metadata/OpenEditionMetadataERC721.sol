// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";

import {Base64} from "@solady/utils/Base64.sol";
import {LibString} from "@solady/utils/LibString.sol";

library OpenEditionMetadataStorage {

    /// @custom:storage-location erc7201:token.metadata.openedition
    bytes32 public constant OPEN_EDITION_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.metadata.openedition")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice shared token metadata
        OpenEditionMetadataERC721.SharedMetadata sharedMetadata;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = OPEN_EDITION_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract OpenEditionMetadataERC721 is Module {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Structure for metadata shared across all tokens
     *
     *  @param name Shared name of NFT in metadata
     *  @param description Shared description of NFT in metadata
     *  @param imageURI Shared URI of image to render for NFTs
     *  @param animationURI Shared URI of animation to render for NFTs
     */
    struct SharedMetadata {
        string name;
        string description;
        string imageURI;
        string animationURI;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev EIP-4906: Emitted when shared metadata is updated
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @notice Emitted when the metadata URI is queried for non-existent token.
    error BatchMetadataNoMetadataForTokenId();

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](1);

        config.callbackFunctions[0] = CallbackFunction(this.onTokenURI.selector);
        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setSharedMetadata.selector, permissionBits: Role._MINTER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.supportedInterfaces = new bytes4[](1);
        config.supportedInterfaces[0] = 0x49064906; // ERC4906.
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) external view returns (string memory) {
        SharedMetadata memory info = OpenEditionMetadataStorage.data().sharedMetadata;

        if (bytes(info.name).length == 0 && bytes(info.description).length == 0 && bytes(info.imageURI).length == 0) {
            revert BatchMetadataNoMetadataForTokenId();
        }

        return _createMetadataEdition({
            name: info.name,
            description: info.description,
            imageURI: info.imageURI,
            animationURI: info.animationURI,
            tokenOfEdition: _id
        });
    }

    /*//////////////////////////////////////////////////////////////
                           FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set shared metadata for NFTs
    function setSharedMetadata(SharedMetadata calldata _metadata) external {
        OpenEditionMetadataStorage.data().sharedMetadata = _metadata;

        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Generates open edition metadata as base64-json blob
    function _createMetadataEdition(
        string memory name,
        string memory description,
        string memory imageURI,
        string memory animationURI,
        uint256 tokenOfEdition
    ) internal pure returns (string memory) {
        string memory tokenMediaData = _tokenMediaData(imageURI, animationURI);
        bytes memory json = _createMetadataJSON(name, description, tokenMediaData, tokenOfEdition);
        return _encodeMetadataJSON(json);
    }

    /**
     * @param name Name of NFT in metadata
     * @param description Description of NFT in metadata
     * @param mediaData Data for media to include in json object
     * @param tokenOfEdition Token ID for specific token
     */
    function _createMetadataJSON(
        string memory name,
        string memory description,
        string memory mediaData,
        uint256 tokenOfEdition
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '{"name": "',
            name,
            " ",
            LibString.toString(tokenOfEdition),
            '", "',
            'description": "',
            description,
            '", "',
            mediaData,
            'properties": {"number": ',
            LibString.toString(tokenOfEdition),
            ', "name": "',
            name,
            '"}}'
        );
    }

    /// Encodes the argument json bytes into base64-data uri format
    /// @param json Raw json to base64 and turn into a data-uri
    function _encodeMetadataJSON(bytes memory json) internal pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /// Generates edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    function _tokenMediaData(string memory imageUrl, string memory animationUrl)
        internal
        pure
        returns (string memory)
    {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        if (hasImage && hasAnimation) {
            return string(abi.encodePacked('image": "', imageUrl, '", "animation_url": "', animationUrl, '", "'));
        }
        if (hasImage) {
            return string(abi.encodePacked('image": "', imageUrl, '", "'));
        }
        if (hasAnimation) {
            return string(abi.encodePacked('animation_url": "', animationUrl, '", "'));
        }

        return "";
    }

}
