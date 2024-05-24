// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

import {BeforeMintCallbackERC721} from "../../../callback/BeforeMintCallbackERC721.sol";

contract PermissionedMintERC721 is ModularExtension, BeforeMintCallbackERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when an unauthorized caller attempts to mint tokens.
    error PermissionedMintUnauthorized();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC721.selector, CallType.CALL);
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(
        address _caller,
        address _to,
        uint256 _startTokenId,
        uint256 _quantity,
        bytes memory _data
    ) external payable virtual override returns (bytes memory) {
        if (!OwnableRoles(msg.sender).hasAllRoles(_caller, Role._MINTER_ROLE)) {
            revert PermissionedMintUnauthorized();
        }
    }
}
