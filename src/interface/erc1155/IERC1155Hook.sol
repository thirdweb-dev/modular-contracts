// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extension/IHook.sol";

interface IERC1155Hook is IHook {
    /*//////////////////////////////////////////////////////////////
                                STRUCT
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice A struct for internal use. The details around which to execute a mint, returned by the beforeMint hook.
     *  @param tokenIdToMint The token ID to start minting the given quantity tokens from.
     *  @param totalPrice The total price to pay to mint the tokens.
     *  @param currency The currency in which to pay for the tokens.
     *  @param quantityToMint The quantity of tokens to mint.
     */
    struct MintParams {
        uint256 tokenIdToMint;
        uint256 totalPrice;
        address currency;
        uint96 quantityToMint;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to call a hook that is not implemented.
    error ERC1155HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external view returns (string memory argSignature);

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address to, uint256 id, uint256 value, bytes memory encodedArgs)
        external
        payable
        returns (MintParams memory details);

    function beforeTransfer(address from, address to, uint256 id, uint256 value) external;

    function beforeBurn(address from, uint256 id, uint256 value) external;

    function beforeApprove(address from, address to, bool approved) external;

    function uri(uint256 id) external view returns (string memory metadata);

    function royaltyInfo(uint256 id, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
