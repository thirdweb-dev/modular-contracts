// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";
import {LibString} from "@solady/utils/LibString.sol";

library SimpleMetadataStorage {
    /// @custom:storage-location erc7201:simple.metadata.storage
    bytes32 public constant SIMPLE_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("simple.metadata.storage")) - 1)) & ~bytes32(uint256(0xff));

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

contract SimpleMetadata is IExtensionContract {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the base URI for a token is updated.
    event MetadataUpdate(address indexed token, uint256 id);

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](1);
        config.extensionABI = new ExtensionFunction[](1);

        config.callbackFunctions[0] = this.onTokenURI.selector;
        config.extensionABI[0] =
            ExtensionFunction({selector: this.setTokenURI.selector, callType: CallType.CALL, permissioned: true});
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) public view returns (string memory) {
        return SimpleMetadataStorage.data().uris[msg.sender][_id];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
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
