// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../common/Initializable.sol";
import "../common/UUPSUpgradeable.sol";
import "../common/Permission.sol";

import {IERC20Extension} from "../interface/extension/IERC20Extension.sol";

abstract contract ERC20Extension is Initializable, UUPSUpgradeable, Permission, IERC20Extension {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint extension.
    function BEFORE_MINT_FLAG() public pure virtual returns (uint256) {
        return 2 ** 1;
    }

    /// @notice Bits representing the before transfer extension.
    function BEFORE_TRANSFER_FLAG() public pure virtual returns (uint256) {
        return 2 ** 2;
    }

    /// @notice Bits representing the before burn extension.
    function BEFORE_BURN_FLAG() public pure virtual returns (uint256) {
        return 2 ** 3;
    }

    /// @notice Bits representing the before approve extension.
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
    function __ERC20Extension_init(address _upgradeAdmin) public onlyInitializing {
        _setupRole(_upgradeAdmin, ADMIN_ROLE_BITS);
    }

    /// @notice Checks if `msg.sender` is authorized to upgrade the proxy to `newImplementation`, reverting if not.
    function _authorizeUpgrade(address) internal view override {
        if (!hasRole(msg.sender, ADMIN_ROLE_BITS)) {
            revert ERC20UnauthorizedUpgrade();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the signature of the arguments expected by the beforeMint extension.
    function getBeforeMintArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /// @notice Returns the signature of the arguments expected by the beforeBurn extension.
    function getBeforeBurnArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint extension that is called by a core token before minting tokens.
     *  @param _to The address that is minting tokens.
     *  @param _amount The amount of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint extension.
     *  @return quantityToMint The quantity of tokens to mint.s
     */
    function beforeMint(address _to, uint256 _amount, bytes memory _encodedArgs)
        external
        payable
        virtual
        returns (uint256 quantityToMint)
    {
        revert ERC20ExtensionNotImplemented();
    }

    /**
     *  @notice The beforeTransfer extension that is called by a core token before transferring tokens.
     *  @param _from The address that is transferring tokens.
     *  @param _to The address that is receiving tokens.
     *  @param _amount The amount of tokens being transferred.
     */
    function beforeTransfer(address _from, address _to, uint256 _amount) external virtual {
        revert ERC20ExtensionNotImplemented();
    }

    /**
     *  @notice The beforeBurn extension that is called by a core token before burning tokens.
     *  @param _from The address that is burning tokens.
     *  @param _amount The amount of tokens being burned.
     *  @param _encodedArgs The encoded arguments for the beforeBurn extension.
     */
    function beforeBurn(address _from, uint256 _amount, bytes memory _encodedArgs) external virtual {
        revert ERC20ExtensionNotImplemented();
    }

    /**
     *  @notice The beforeApprove extension that is called by a core token before approving tokens.
     *  @param _from The address that is approving tokens.
     *  @param _to The address that is being approved.
     *  @param _amount The amount of tokens being approved.
     */
    function beforeApprove(address _from, address _to, uint256 _amount) external virtual {
        revert ERC20ExtensionNotImplemented();
    }
}
