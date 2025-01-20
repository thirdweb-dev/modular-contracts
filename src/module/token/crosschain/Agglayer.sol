// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";
import {CrossChain} from "./CrossChain.sol";
import {IPolygonZkEVMBridge} from "@zkevm-contracts/interfaces/IPolygonZkEVMBridge.sol";
import {IERC20} from "src/interface/IERC20.sol";

interface IBridge is IPolygonZkEVMBridge {
    function networkID() external view returns(uint32);
}

interface IBridgeExtension {
    function bridge() external view returns(address);

    function bridgeAndCall(
        address token,
        uint256 amount,
        bytes calldata permitData,
        uint32 destinationNetwork,
        address callAddress,
        address fallbackAddress,
        bytes calldata callData,
        bool forceUpdateGlobalExitRoot
    ) external payable;
}

library AgglayerCrossChainStorage {

    /// @custom:storage-location erc7201:token.bridgeAndCall
    bytes32 public constant BRIDGE_AND_CALL_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.bridgeAndCall")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address router;
        address bridge;
        uint32 networkId;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = BRIDGE_AND_CALL_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract AgglayerCrossChain is Module, CrossChain {

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](5);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getRouter.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setRouter.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.sendCrossChainTransaction.selector, permissionBits: 0});
        config.fallbackFunctions[3] = FallbackFunction({selector: this.claimMessage.selector, permissionBits: 0});
        config.fallbackFunctions[4] = FallbackFunction({selector: this.claimAsset.selector, permissionBits: 0});

        config.registerInstallationCallback = true;
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        (address router) = abi.decode(data, (address));
        address bridge = IBridgeExtension(router).bridge();
        
        _agglayerStorage().router = router;
        _agglayerStorage().bridge = bridge;
        _agglayerStorage().networkId = IBridge(bridge).networkID();
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

    function getRouter() external view override returns (address) {
        return _agglayerStorage().router;
    }

    function setRouter(address router) external override {
        _agglayerStorage().router = router;
    }

    function sendCrossChainTransaction(
        uint64 _destinationNetwork,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable override {
        (
            address _fallbackAddress,
            bool _forceUpdateGlobalExitRoot,
            address _token,
            uint256 _amount,
            bytes memory permitData
        ) = abi.decode(_extraArgs, (address, bool, address, uint256, bytes));

        if (_token == address(0) && _amount == 0) {
            _bridgeMessage(uint32(_destinationNetwork), _callAddress, _forceUpdateGlobalExitRoot, _payload);
        } else if (_payload.length == 0) {
            _bridgeAsset(
                uint32(_destinationNetwork), _callAddress, _amount, _token, _forceUpdateGlobalExitRoot, permitData
            );
        } else {
            _bridgeAndCall(
                _token,
                _amount,
                permitData,
                uint32(_destinationNetwork),
                _callAddress,
                _fallbackAddress,
                _payload,
                _forceUpdateGlobalExitRoot
            );
        }

        onCrossChainTransactionSent(_destinationNetwork, _callAddress, _payload, _extraArgs);
    }

    function claimMessage(
        bytes32[32] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external {
        IBridge(_agglayerStorage().bridge).claimMessage(
            smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            originNetwork,
            originAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    function claimAsset(
        bytes32[32] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external {
        IBridge(_agglayerStorage().bridge).claimAsset(
            smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _bridgeMessage(
        uint32 _destinationNetwork,
        address _callAddress,
        bool _forceUpdateGlobalExitRoot,
        bytes memory _payload
    ) internal {
        IBridge(_agglayerStorage().bridge).bridgeMessage(
            uint32(_destinationNetwork), _callAddress, _forceUpdateGlobalExitRoot, _payload
        );
    }

    function _bridgeAsset(
        uint32 _destinationNetwork,
        address _callAddress,
        uint256 _amount,
        address _token,
        bool _forceUpdateGlobalExitRoot,
        bytes memory permitData
    ) internal {
        address bridge = _agglayerStorage().bridge;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token).approve(bridge, _amount);

        IBridge(bridge).bridgeAsset(
            uint32(_destinationNetwork), _callAddress, _amount, _token, _forceUpdateGlobalExitRoot, permitData
        );
    }

    function _bridgeAndCall(
        address _token,
        uint256 _amount,
        bytes memory permitData,
        uint32 _destinationNetwork,
        address _callAddress,
        address _fallbackAddress,
        bytes memory _payload,
        bool _forceUpdateGlobalExitRoot
    ) internal {
        address router = _agglayerStorage().router;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token).approve(router, _amount);

        IBridgeExtension(router).bridgeAndCall(
            _token,
            _amount,
            permitData,
            _destinationNetwork,
            _callAddress,
            _fallbackAddress,
            _payload,
            _forceUpdateGlobalExitRoot
        );
    }

    function onCrossChainTransactionSent(
        uint64 _destinationNetwork,
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

    function _agglayerStorage() internal pure returns (AgglayerCrossChainStorage.Data storage) {
        return AgglayerCrossChainStorage.data();
    }

}
