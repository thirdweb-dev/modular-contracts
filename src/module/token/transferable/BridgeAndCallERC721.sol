// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {BeforeTransferCallbackERC721} from "../../../callback/BeforeTransferCallbackERC721.sol";
import {IBridgeAndCall} from "@lxly-bridge-and-call/IBridgeAndCall.sol";

library BridgeAndCallStorage {
    /// @custom:storage-location erc7201:token.bridgeAndCall
    bytes32 public constant BRIDGE_AND_CALL_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.bridgeAndCall")) - 1)) &
            ~bytes32(uint256(0xff));

    struct Data {
        address bridgeExtension;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BRIDGE_AND_CALL_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract BridgeAndCallERC721 is ModularExtension, BeforeTransferCallbackERC721 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on attempt to transfer a token when the bridge extension is not set.
    error bridgeExtensionNotSet();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig()
        external
        pure
        override
        returns (ExtensionConfig memory config)
    {
        config.fallbackFunctions = new FallbackFunction[](4);

        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.getBridgeExtension.selector,
            permissionBits: 0
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setBridgeExtension.selector,
            permissionBits: Role._MANAGER_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.bridgeAndCall.selector,
            permissionBits: 0
        });

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.registerInstallationCallback = true;
    }

    /// @dev Called by a Core into an Extension during the installation of the Extension.
    function onInstall(bytes calldata data) external {
        address bridgeExtension = abi.decode(data, (address));
        _bridgeAndCallStorage().bridgeExtension = bridgeExtension;
    }

    /// @dev Called by a Core into an Extension during the uninstallation of the Extension.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers is enabled for the token.
    function getBridgeExtension() external view returns (address) {
        return _bridgeAndCallStorage().bridgeExtension;
    }

    /// @notice Set transferability for a token.
    function setBridgeExtension(address enableTransfer) external {
        _bridgeAndCallStorage().bridgeExtension = enableTransfer;
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
        address bridgeExtension = _bridgeAndCallStorage().bridgeExtension;
        if (bridgeExtension == address(0)) {
            revert bridgeExtensionNotSet();
        }

        IBridgeAndCall(bridgeExtension).bridgeAndCall(
            address(this),
            amount,
            destinationNetwork,
            callAddress,
            fallbackAddress,
            callData,
            forceUpdateGlobalExitRoot
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _bridgeAndCallStorage()
        internal
        pure
        returns (BridgeAndCallStorage.Data storage)
    {
        return BridgeAndCallStorage.data();
    }
}
