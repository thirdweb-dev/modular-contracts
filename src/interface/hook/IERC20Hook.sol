// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "./IHook.sol";
import {IMintRequest} from "../common/IMintRequest.sol";
import {IBurnRequest} from "../common/IBurnRequest.sol";

interface IERC20Hook is IHook, IMintRequest, IBurnRequest {
    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to call a hook that is not implemented.
    error ERC20HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                              HOOK FUNCTIONS
      //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param mintRequest The token mint request details.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata mintRequest) external payable returns (uint256 quantityToMint);

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring a token.
     *  @param from The address that is transferring tokens.
     *  @param to The address that is receiving tokens.
     *  @param amount The quantity of tokens to transfer.
     */
    function beforeTransfer(address from, address to, uint256 amount) external;

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param burnRequest The token burn request details.
     */
    function beforeBurn(BurnRequest calldata burnRequest) external;

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving a token.
     *  @param from The address that is approving tokens.
     *  @param to The address that is being approved.
     *  @param amount The quantity of tokens to approve.
     */
    function beforeApprove(address from, address to, uint256 amount) external;
}
