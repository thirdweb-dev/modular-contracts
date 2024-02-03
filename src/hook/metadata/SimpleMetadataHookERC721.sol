// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IPermission} from "../../interface/common/IPermission.sol";

import {ERC721Hook} from "../ERC721Hook.sol";
import {LibString} from "../../lib/LibString.sol";

import {SimpleMetadataStorage} from "../../storage/hook/metadata/SimpleMetadataStorage.sol";

contract SimpleMetadataHookERC721 is ERC721Hook {
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
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        if (!IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert SimpleMetadataHookNotAuthorized();
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
        hooksImplemented = TOKEN_URI_FLAG;
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function tokenURI(uint256 _id) external view override returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTokenURI(address _token, uint256 _id, string calldata _uri) external onlyAdmin(_token) {
        SimpleMetadataStorage.data().uris[_token][_id] = _uri;
        emit MetadataUpdate(_token, _id);
    }
}
