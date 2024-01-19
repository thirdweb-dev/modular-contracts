// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../extension/IHook.sol";

interface IERC20Hook is IHook {
    /*//////////////////////////////////////////////////////////////
                                STRUCT
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        uint256 totalPrice;
        address currency;
        uint96 quantityToMint;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to call a hook that is not implemented.
    error ERC20HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external view returns (string memory argSignature);

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address to, uint256 amount, bytes memory encodedArgs)
        external
        payable
        returns (MintParams memory details);

    function beforeTransfer(address from, address to, uint256 amount) external;

    function beforeBurn(address from, uint256 amount) external;

    function beforeApprove(address from, address to, uint256 amount) external;
}
