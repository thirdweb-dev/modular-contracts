// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "@solady/utils/Initializable.sol";
import "@solady/utils/UUPSUpgradeable.sol";
import "@solady/auth/Ownable.sol";

import {IERC20Hook} from "../interface/hook/IERC20Hook.sol";

abstract contract ERC20Hook is Initializable, UUPSUpgradeable, Ownable, IERC20Hook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    function BEFORE_MINT_FLAG() public pure virtual returns (uint256) {
        return 2 ** 1;
    }

    /// @notice Bits representing the before transfer hook.
    function BEFORE_TRANSFER_FLAG() public pure virtual returns (uint256) {
        return 2 ** 2;
    }

    /// @notice Bits representing the before burn hook.
    function BEFORE_BURN_FLAG() public pure virtual returns (uint256) {
        return 2 ** 3;
    }

    /// @notice Bits representing the before approve hook.
    function BEFORE_APPROVE_FLAG() public pure virtual returns (uint256) {
        return 2 ** 4;
    }

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    error ERC20UnauthorizedUpgrade();

    /*//////////////////////////////////////////////////////////////
                     CONSTRUCTOR & INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract. Grants admin role (i.e. upgrade authority) to given `_upgradeAdmin`.
    function __ERC20Hook_init(address _upgradeAdmin) public onlyInitializing {
        _setOwner(_upgradeAdmin);
    }

    /// @notice Checks if `msg.sender` is authorized to upgrade the proxy to `newImplementation`, reverting if not.
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != owner()) {
            revert ERC20UnauthorizedUpgrade();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _mintRequest The token mint request details.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata _mintRequest) external payable virtual returns (uint256 quantityToMint) {
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
     *  @notice The beforeBurn hook that is called by a core token before burning a token.
     *  @param _burnRequest The token burn request details.
     */
    function beforeBurn(BurnRequest calldata _burnRequest) external virtual {
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
