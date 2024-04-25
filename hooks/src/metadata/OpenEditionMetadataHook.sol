// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "@core-contracts/interface/IHook.sol";

import {NFTMetadataRenderer} from "../lib/NFTMetadataRenderer.sol";

import {HookFlagsDirectory} from "@core-contracts/callback/HookFlagsDirectory.sol";
import {OnTokenURICallback} from "@core-contracts/callback/OnTokenURICallback.sol";

import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

library SharedMetadataStorage {
    /// @custom:storage-location erc7201:shared.metadata.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("shared.metadata.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant SHARED_METADATA_STORAGE_POSITION =
        0xfdee411af9bf3577111bd01929620c54823736ad38c2fe7a6b62d3e2d7ac0f00;

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

contract OpenEditionMetadataHook is IHook, OnTokenURICallback, HookFlagsDirectory, Multicallable {
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

    /**
     *  @notice Returns all hooks implemented by the contract and all hook contract functions to register as
     *          callable via core contract fallback function.
     */
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = ON_TOKEN_URI_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](1);
        hookInfo.hookFallbackFunctions[0] = HookFallbackFunction(this.setSharedMetadata.selector, CallType.CALL, true);
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) external view override returns (string memory) {
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
