// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC721CoreCustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
    error ERC721CoreMintingDisabled();

    error ERC721CoreMetadataUpdateDisabled();

    /// @notice Emitted on a failed attempt to initialize the contract.
    error ERC721CoreInitializationFailed();
}
