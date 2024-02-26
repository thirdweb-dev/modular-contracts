// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { LibString } from "@solady/utils/LibString.sol";

import { ERC721Hook } from "../ERC721Hook.sol";
import { IPermission } from "../../interface/common/IPermission.sol";

import { SimpleMetadataStorage } from "../../storage/hook/metadata/SimpleMetadataStorage.sol";

contract SimpleMetadataHook is ERC721Hook {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the base URI for a token is updated.
    event MetadataUpdate(address indexed token, uint256 id);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error SimpleMetadataHookNotAuthorized();

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
        hooksImplemented = TOKEN_URI_FLAG();
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function tokenURI(uint256 _id) public view override returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function uri(uint256 _id) external view returns (string memory) {
        return tokenURI(_id);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the base URI for a token.
     *  @param _id The token ID of the NFT.
     *  @param _uri The base URI to set.
     */
    function setTokenURI(uint256 _id, string calldata _uri) external {
        address token = msg.sender;

        SimpleMetadataStorage.data().uris[token][_id] = _uri;
        emit MetadataUpdate(token, _id);
    }
}
