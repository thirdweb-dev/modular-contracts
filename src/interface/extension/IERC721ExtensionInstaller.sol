// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IExtensionInstaller} from "./IExtensionInstaller.sol";

interface IERC721ExtensionInstaller is IExtensionInstaller {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementations of the token extensions.
    struct ERC721Extensions {
        address beforeMint;
        address beforeTransfer;
        address beforeBurn;
        address beforeApprove;
        address tokenURI;
        address royaltyInfo;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's extensions and their implementations.
    function getAllExtensions() external view returns (ERC721Extensions memory extensions);
}
