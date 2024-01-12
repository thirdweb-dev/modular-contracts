// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IPermission} from "../../interface/extension/IPermission.sol";

import {TokenHook} from "../../extension/TokenHook.sol";
import {LibString} from "../../lib/LibString.sol";

contract SimpleMetadataHook is TokenHook {
    using LibString for uint256;
    
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event MetadataUpdate(address indexed token);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => base URI
    mapping(address => string) private _baseURI;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = TOKEN_URI_FLAG;
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function tokenURI(uint256 _id) external view override returns (string memory) {
        return string(abi.encodePacked(_baseURI[msg.sender], _id.toString()));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBaseURI(address _token, string calldata _uri) external onlyAdmin(_token) {
        _baseURI[_token] = _uri;
        emit MetadataUpdate(_token);
    }
}