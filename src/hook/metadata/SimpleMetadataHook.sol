// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {ERC721Hook} from "../ERC721Hook.sol";

import {SimpleMetadataStorage} from "../../storage/hook/metadata/SimpleMetadataStorage.sol";

contract SimpleMetadataHook is ERC721Hook, Multicallable {
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
        hooksImplemented = ON_TOKEN_URI_FLAG();
    }

    /// @notice Returns all hook contract functions to register as callable via core contract fallback function.
    function getHookFallbackFunctions() external view returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.setTokenURI.selector;
        return selectors;
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onUri(uint256 _id) external view returns (string memory) {
        return onTokenURI(_id);
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
