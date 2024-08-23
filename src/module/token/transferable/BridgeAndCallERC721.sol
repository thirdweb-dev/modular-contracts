// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ModularModule} from "../../../ModularModule.sol";
import {Role} from "../../../Role.sol";
import {BeforeTransferCallbackERC721} from "../../../callback/BeforeTransferCallbackERC721.sol";
import {IBridgeAndCall} from "@lxly-bridge-and-call/IBridgeAndCall.sol";

library BridgeAndCallStorage {

    /// @custom:storage-location erc7201:token.bridgeAndCall
    bytes32 public constant BRIDGE_AND_CALL_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.bridgeAndCall")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address bridgeModule;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BRIDGE_AND_CALL_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract BridgeAndCallERC721 is ModularModule, BeforeTransferCallbackERC721 {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on attempt to transfer a token when the bridge extension is not set.
    error bridgeModuleNotSet();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](4);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getBridgeModule.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setBridgeModule.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.bridgeAndCall.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.registerInstallationCallback = true;
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address bridgeModule = abi.decode(data, (address));
        _bridgeAndCallStorage().bridgeModule = bridgeModule;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers is enabled for the token.
    function getBridgeModule() external view returns (address) {
        return _bridgeAndCallStorage().bridgeModule;
    }

    /// @notice Set transferability for a token.
    function setBridgeModule(address enableTransfer) external {
        _bridgeAndCallStorage().bridgeModule = enableTransfer;
    }

    /// @notice Set transferability for a token.
    function bridgeAndCall(
        uint256 amount,
        uint32 destinationNetwork,
        address callAddress,
        address fallbackAddress,
        bytes calldata callData,
        bool forceUpdateGlobalExitRoot
    ) external {
        address bridgeModule = _bridgeAndCallStorage().bridgeModule;
        if (bridgeModule == address(0)) {
            revert bridgeModuleNotSet();
        }

        IBridgeAndCall(bridgeModule).bridgeAndCall(
            address(this), amount, destinationNetwork, callAddress, fallbackAddress, callData, forceUpdateGlobalExitRoot
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _bridgeAndCallStorage() internal pure returns (BridgeAndCallStorage.Data storage) {
        return BridgeAndCallStorage.data();
    }

}
