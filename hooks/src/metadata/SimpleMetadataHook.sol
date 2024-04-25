// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "@core-contracts/interface/IHook.sol";

import {HookFlagsDirectory} from "@core-contracts/callback/HookFlagsDirectory.sol";
import {OnTokenURICallback} from "@core-contracts/callback/OnTokenURICallback.sol";

import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

library SimpleMetadataStorage {
    /// @custom:storage-location erc7201:simple.metadata.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("simple.metadata.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant SIMPLE_METADATA_STORAGE_POSITION =
        0x8ec6ff141fffd07767dee37f0023e9d3be86f52ffb0ca9c1e2ac0369422b1900;

    struct Data {
        /// @notice Mapping from token => base URI
        mapping(address => mapping(uint256 => string)) uris;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SIMPLE_METADATA_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract SimpleMetadataHook is IHook, HookFlagsDirectory, OnTokenURICallback, Multicallable {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the base URI for a token is updated.
    event MetadataUpdate(address indexed token, uint256 id);

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
        hookInfo.hookFallbackFunctions[0] = HookFallbackFunction(this.setTokenURI.selector, CallType.CALL, true);
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) public view override returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
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
