// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";
import {NFTMetadataRenderer} from "../lib/NFTMetadataRenderer.sol";

library SharedMetadataStorage {
    /// @custom:storage-location erc7201:open.edition.metadata.storage
    bytes32 public constant SHARED_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("open.edition.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        /// @notice Token metadata information
        mapping(address => OpenEditionMetadataHook.SharedMetadataInfo) sharedMetadata;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SHARED_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract OpenEditionMetadataHook is IExtensionContract {
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
    struct SharedMetadataInfo {
        string name;
        string description;
        string imageURI;
        string animationURI;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event SharedMetadataUpdated(address token, string name, string description, string imageURI, string animationURI);
    event BatchMetadataUpdate(address indexed token, uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.extensionABI = new ExtensionFunction[](1);

        config.callbackFunctions[0] = this.onTokenURI.selector;
        config.extensionABI[0] =
            ExtensionFunction({selector: this.setSharedMetadata.selector, callType: CallType.CALL, permissioned: true});
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) external view returns (string memory) {
        return _getURIFromSharedMetadata(msg.sender, _id);
    }

    /*//////////////////////////////////////////////////////////////
                        Shared metadata logic
    //////////////////////////////////////////////////////////////*/

    /// @notice Set shared metadata for NFTs
    function setSharedMetadata(SharedMetadataInfo calldata _metadata) external {
        address token = msg.sender;

        SharedMetadataStorage.data().sharedMetadata[token] = SharedMetadataInfo({
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

    /**
     *  @dev Token URI information getter
     *  @param tokenId Token ID to get URI for
     */
    function _getURIFromSharedMetadata(address _token, uint256 tokenId) internal view returns (string memory) {
        SharedMetadataInfo memory info = SharedMetadataStorage.data().sharedMetadata[_token];

        return NFTMetadataRenderer.createMetadataEdition({
            name: info.name,
            description: info.description,
            imageURI: info.imageURI,
            animationURI: info.animationURI,
            tokenOfEdition: tokenId
        });
    }
}
