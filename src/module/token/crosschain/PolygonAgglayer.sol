// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";

import {CrossChain} from "./CrossChain.sol";
import {IBridgeAndCall} from "@lxly-bridge-and-call/IBridgeAndCall.sol";

library PolygonAgglayerCrossChainStorage {

    /// @custom:storage-location erc7201:token.bridgeAndCall
    bytes32 public constant BRIDGE_AND_CALL_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.bridgeAndCall")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address router;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BRIDGE_AND_CALL_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract PolygonAgglayerCrossChainERC721 is Module, CrossChain {

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](3);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getRouter.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setRouter.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.sendCrossChainTransaction.selector, permissionBits: 0});
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address router = abi.decode(data, (address));
        _polygonAgglayerStorage().router = router;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address router) external pure returns (bytes memory) {
        return abi.encode(router);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers is enabled for the token.
    function getRouter() external view override returns (address) {
        return _polygonAgglayerStorage().router;
    }

    /// @notice Set transferability for a token.
    function setRouter(address router) external override {
        _polygonAgglayerStorage().router = router;
    }

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable override {
        address router = _polygonAgglayerStorage().router;
        (address _fallbackAddress, bool _forceUpdateGlobalExitRoot, address _token, uint256 _amount) =
            abi.decode(_extraArgs, (address, bool, address, uint256));

        IBridgeAndCall(router).bridgeAndCall(
            _token,
            _amount,
            uint32(_destinationChain),
            _callAddress,
            _fallbackAddress,
            _payload,
            _forceUpdateGlobalExitRoot
        );

        onCrossChainTransactionSent(_destinationChain, _callAddress, _payload, _extraArgs);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function onCrossChainTransactionSent(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) internal override {
        /// post cross chain transaction sent logic goes here
    }

    function onCrossChainTransactionReceived(
        uint64 _sourceChain,
        address _sourceAddress,
        bytes memory _payload,
        bytes memory _extraArgs
    ) internal override {
        /// post cross chain transaction received logic goes here
    }

    function _polygonAgglayerStorage() internal pure returns (PolygonAgglayerCrossChainStorage.Data storage) {
        return PolygonAgglayerCrossChainStorage.data();
    }

}
