// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC1155CoreCustomErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
    error ERC1155CoreMintingDisabled();
}
