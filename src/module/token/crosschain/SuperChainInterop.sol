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

// Inherit from OP repo once implemented
interface ICrossChainERC20 {
    function crosschainMint(address _account, uint256 _amount) external;
    function crosschainBurn(address _account, uint256 _amount) external;
    event CrosschainMinted(address indexed _to, uint256 _amount);
    event CrosschainBurnt(address indexed _from, uint256 _amount);
}

library SuperChainInteropStorage {

    /// @custom:storage-location erc7201:crosschain.superchain.erc20
    bytes32 public constant SUPERCHAIN_ERC20_POSITION =
        keccak256(abi.encode(uint256(keccak256("crosschain.superchain.erc20")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address superchainBridge;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SUPERCHAIN_ERC20_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract SuperChainInterop is ERC20, Module, IInstallationCallback, ICrossChainERC20 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when the minting request signature is unauthorized.
    error SuperChainInteropNotSuperChainBridge();

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](4);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.crosschainMint.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.crosschainBurn.selector, permissionBits: 0});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.getSuperChainBridge.selector, permissionBits: 0});
        config.fallbackFunctions[3] = FallbackFunction({selector: this.setSuperChainBridge.selector, permissionBits: Role._MANAGER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x36372b07; // ERC20

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "SuperChainInterop";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "SC20";
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySuperchainERC20Bridge() {
        if (msg.sender != _superchainInteropStorage().superchainBridge) {
            revert SuperChainInteropNotSuperChainBridge();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    onInstall / onUninstall 
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address superchainBridge = abi.decode(data, (address));
        _superchainInteropStorage().superchainBridge = superchainBridge;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address superchainBridge) external pure returns (bytes memory) {
        return abi.encode(superchainBridge);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice performs a crosschain mint
    function crosschainMint(address _account, uint256 _amount) external onlySuperchainERC20Bridge {
        _mint(_account, _amount);

        emit CrosschainMinted(_account, _amount);
    }

    /// @notice performs a crosschain burn
    function crosschainBurn(address _account, uint256 _amount) external onlySuperchainERC20Bridge {
        _burn(_account, _amount);

        emit CrosschainBurnt(_account, _amount);
    }

    /// @notice returns the superchain bridge address
    function getSuperChainBridge() external view returns (address) {
        return _superchainInteropStorage().superchainBridge;
    }

    /// @notice sets the superchain bridge address
    function setSuperChainBridge(address _superchainBridge) external {
        _superchainInteropStorage().superchainBridge = _superchainBridge;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _superchainInteropStorage() internal pure returns (SuperChainInteropStorage.Data storage) {
        return SuperChainInteropStorage.data();
    }

}
