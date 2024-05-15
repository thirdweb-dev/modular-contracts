// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";
import {NFTMetadataRenderer} from "../lib/NFTMetadataRenderer.sol";

library OpenEditionMetadataStorage {
    /// @custom:storage-location erc7201:open.edition.metadata.storage
    bytes32 public constant OPEN_EDITION_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("open.edition.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice Token metadata information
        mapping(address => OpenEditionMetadata.SharedMetadata) sharedMetadata;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = OPEN_EDITION_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract OpenEditionMetadata is IExtensionContract {
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

    /// @dev Emittted when shared metadata is updated
    event SharedMetadataUpdated(address token, string name, string description, string imageURI, string animationURI);

    /// @dev EIP-4906: Emitted when shared metadata is updated
    event BatchMetadataUpdate(address indexed token, uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.extensionABI = new ExtensionFunction[](1);

        config.callbackFunctions[0] = this.onTokenURI.selector;
        config.extensionABI[0] =
            ExtensionFunction({selector: this.setSharedMetadata.selector, callType: CallType.CALL, permissioned: true});
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721Metadata.tokenURI
    function onTokenURI(uint256 _id) external view returns (string memory) {
        address token = msg.sender;
        SharedMetadata memory info = OpenEditionMetadataStorage.data().sharedMetadata[token];
        return NFTMetadataRenderer.createMetadataEdition({
            name: info.name,
            description: info.description,
            imageURI: info.imageURI,
            animationURI: info.animationURI,
            tokenOfEdition: _id
        });
    }

    /*//////////////////////////////////////////////////////////////
                        EXTENSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set shared metadata for NFTs
    function setSharedMetadata(SharedMetadata calldata _metadata) external {
        address token = msg.sender;

        OpenEditionMetadataStorage.data().sharedMetadata[token] = SharedMetadata({
            name: _metadata.name,
            description: _metadata.description,
            imageURI: _metadata.imageURI,
            animationURI: _metadata.animationURI
        });

        emit BatchMetadataUpdate(token, 0, type(uint256).max);

        emit SharedMetadataUpdated(
            token, _metadata.name, _metadata.description, _metadata.imageURI, _metadata.animationURI
        );
    }
}
