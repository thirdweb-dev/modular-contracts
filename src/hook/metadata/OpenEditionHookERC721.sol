// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IPermission } from "../../interface/common/IPermission.sol";

import { ERC721Hook } from "../ERC721Hook.sol";
import { NFTMetadataRenderer } from "../../lib/NFTMetadataRenderer.sol";

import { SharedMetadataStorage } from "../../storage/hook/metadata/SharedMetadataStorage.sol";
import { ISharedMetadata } from "../../interface/common/ISharedMetadata.sol";

contract OpenEditionHookERC721 is ISharedMetadata, ERC721Hook {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error OpenEditionHookNotAuthorized();

    error OpenEditionHookInvalidRange();

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert OpenEditionHookNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZE
    //////////////////////////////////////////////////////////////*/

    function initialize(address _upgradeAdmin) public initializer {
        __ERC721Hook_init(_upgradeAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = TOKEN_URI_FLAG & METADATA_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the setMetadata hook.
    function getSetMetadataArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "string,string,string,string";
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function tokenURI(uint256 _id) external view override returns (string memory) {
        return _getURIFromSharedMetadata(msg.sender, _id);
    }

    /*//////////////////////////////////////////////////////////////
                        Shared metadata logic
    //////////////////////////////////////////////////////////////*/

    /// @notice Set shared metadata for NFTs
    function setBatchMetadata(uint256 startTokenId, uint256 endTokenId, bytes memory _encodedArgs) external override {
        if (startTokenId != 0 || endTokenId != type(uint256).max) {
            revert OpenEditionHookInvalidRange();
        }

        address _token = msg.sender;
        SharedMetadataInfo memory _metadata = abi.decode(_encodedArgs, (SharedMetadataInfo));
        _setSharedMetadata(_token, _metadata);
    }

    /**
     *  @dev Sets shared metadata for NFTs.
     *  @param _metadata common metadata for all tokens
     */
    function _setSharedMetadata(address _token, SharedMetadataInfo memory _metadata) internal {
        SharedMetadataStorage.data().sharedMetadata[_token] = SharedMetadataInfo({
            name: _metadata.name,
            description: _metadata.description,
            imageURI: _metadata.imageURI,
            animationURI: _metadata.animationURI
        });

        emit SharedMetadataUpdated(
            _token,
            _metadata.name,
            _metadata.description,
            _metadata.imageURI,
            _metadata.animationURI
        );
    }

    /**
     *  @dev Token URI information getter
     *  @param tokenId Token ID to get URI for
     */
    function _getURIFromSharedMetadata(address _token, uint256 tokenId) internal view returns (string memory) {
        SharedMetadataInfo memory info = SharedMetadataStorage.data().sharedMetadata[_token];

        return
            NFTMetadataRenderer.createMetadataEdition({
                name: info.name,
                description: info.description,
                imageURI: info.imageURI,
                animationURI: info.animationURI,
                tokenOfEdition: tokenId
            });
    }
}
