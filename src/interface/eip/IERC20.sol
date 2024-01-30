// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are transferrred.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when an owner updates their allowance to a spender.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total circulating supply of tokens.
    function totalSupply() external view returns (uint256);

    /**
     *  @notice Returns the balance of the given address.
     *  @param owner The address to query balance for.
     *  @return balance The quantity of tokens owned by `owner`.
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     *  @notice Returns the allowance of a spender to spend a given owner's tokens.
     *  @param owner The address that owns the tokens.
     *  @param spender The address that is approved to spend tokens.
     *  @return allowance The quantity of tokens `spender` is allowed to spend on behalf of `owner`.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     *  @notice Transfers tokens to a recipient.
     *  @param to The address to transfer tokens to.
     *  @param value The quantity of tokens to transfer.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     *  @notice Approves a spender to spend tokens on behalf of an owner.
     *  @param spender The address to approve spending on behalf of the token owner.
     *  @param value The quantity of tokens to approve.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     *  @notice Transfers tokens from a sender to a recipient.
     *  @param from The address to transfer tokens from.
     *  @param to The address to transfer tokens to.
     *  @param value The quantity of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
