// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";
import {IMintFeeManager} from "../../../interface/IMintFeeManager.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BeforeMintCallbackERC20} from "../../../callback/BeforeMintCallbackERC20.sol";
import {BeforeMintWithSignatureCallbackERC20} from "../../../callback/BeforeMintWithSignatureCallbackERC20.sol";

library SuperChainERC20Storage {

    /// @custom:storage-location erc7201:crosschain.superchain.erc20
    bytes32 public constant SUPERCHAIN_ERC20_POSITION =
        keccak256(abi.encode(uint256(keccak256("crosschain.superchain.erc20")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address superchainERC20Bridge;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SUPERCHAIN_ERC20_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract SuperChainERC20 is ERC20, Module, IInstallationCallback {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when the minting request signature is unauthorized.
    error SuperChainERC20SignatureMintUnauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event CrosschainMinted(address indexed _to, uint256 _amount);

    event CrosschainBurnt(address indexed _from, uint256 _amount);

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](2);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.crosschainMint.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.crosschainBurn.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x36372b07; // ERC20

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "SuperChainERC20";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "SC20";
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySuperchainERC20Bridge() {
        if (msg.sender != _superchainERC20Storage().superchainERC20Bridge) {
            revert SuperChainERC20SignatureMintUnauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    onInstall / onUninstall 
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address superchainERC20Bridge = abi.decode(data, (address));
        _superchainERC20Storage().superchainERC20Bridge = superchainERC20Bridge;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address superchainERC20Bridge) external pure returns (bytes memory) {
        return abi.encode(superchainERC20Bridge);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function crosschainMint(address _account, uint256 _amount) external onlySuperchainERC20Bridge {
        _mint(_account, _amount);

        emit CrosschainMinted(_account, _amount);
    }

    /// @notice Sets the sale configuration for a token.
    function crosschainBurn(address _account, uint256 _amount) external onlySuperchainERC20Bridge {
        _burn(_account, _amount);

        emit CrosschainBurnt(_account, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _superchainERC20Storage() internal pure returns (SuperChainERC20Storage.Data storage) {
        return SuperChainERC20Storage.data();
    }

}
