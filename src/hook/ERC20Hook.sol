// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IERC20Hook} from "../interface/hook/IERC20Hook.sol";

abstract contract ERC20Hook is IERC20Hook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /// @notice Returns the signature of the arguments expected by the beforeBurn hook.
    function getBeforeBurnArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting tokens.
     *  @param _to The address that is minting tokens.
     *  @param _amount The amount of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return quantityToMint The quantity of tokens to mint.s
     */
    function beforeMint(address _to, uint256 _amount, bytes memory _encodedArgs)
        external
        payable
        virtual
        returns (uint256 quantityToMint)
    {
        revert ERC20HookNotImplemented();
    }

    /**
     *  @notice The beforeTransfer hook that is called by a core token before transferring tokens.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _amount The amount of tokens being transferred.
     */
    function beforeTransfer(address _from, address _to, uint256 _amount) external virtual {
        revert ERC20HookNotImplemented();
    }

    /**
     *  @notice The beforeBurn hook that is called by a core token before burning tokens.
     *  @param _from The address that is burning tokens.
     *  @param _amount The amount of tokens being burned.
     *  @param _encodedArgs The encoded arguments for the beforeBurn hook.
     */
    function beforeBurn(address _from, uint256 _amount, bytes memory _encodedArgs) external virtual {
        revert ERC20HookNotImplemented();
    }

    /**
     *  @notice The beforeApprove hook that is called by a core token before approving tokens.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _amount The amount of tokens being approved.
     */
    function beforeApprove(address _from, address _to, uint256 _amount) external virtual {
        revert ERC20HookNotImplemented();
    }
}
