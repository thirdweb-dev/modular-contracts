// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";

import {CrossChain} from "./CrossChain.sol";

import {MessagingFee, OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

contract LayerZeroCrossChain is Module, OApp, CrossChain {

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) {}

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](3);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getRouter.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setRouter.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.sendCrossChainTransaction.selector, permissionBits: 0});
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRouter() external view override returns (address) {
        return address(endpoint);
    }

    function setRouter(address _router) external override {}

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable override {
        (bytes memory options, uint256 zroTokenAmount) = abi.decode(_extraArgs, (bytes, uint256));

        _lzSend(
            uint32(_destinationChain),
            _payload,
            options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, zroTokenAmount),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );

        onCrossChainTransactionSent(_destinationChain, _callAddress, _payload, _extraArgs);
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address _sourceAddress, // Executor address as specified by the OApp.
        bytes calldata _extraArgs // Any extra data or options to trigger on receipt.
    ) internal override {
        bytes memory extraArgs = abi.encode(_origin, _guid, _extraArgs);

        onCrossChainTransactionReceived(_origin.srcEid, _sourceAddress, payload, extraArgs);
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

}
