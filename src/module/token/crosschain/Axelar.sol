// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";

import {CrossChain} from "./CrossChain.sol";
import {AxelarExecutable} from "@axelar-network/sdk-solidity/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/sdk-solidity/interfaces/IAxelarGateway.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

contract AxelarCrossChain is Module, AxelarExecutable, CrossChain {

    constructor(address _axelarGateway) AxelarExecutable(_axelarGateway) {}

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
        return address(gateway);
    }

    function setRouter(address _router) external override {}

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable override {
        (string memory destinationChain, string memory contractAddress, bytes memory tokenData) =
            abi.decode(_extraArgs, (string, string, bytes));

        if (tokenData.length > 0) {
            (string memory symbol, uint256 amount) = abi.decode(tokenData, (string, uint256));
            gateway.callContractWithToken(destinationChain, contractAddress, _payload, symbol, amount);
        } else {
            gateway.callContract(destinationChain, contractAddress, _payload);
        }

        onCrossChainTransactionSent(_destinationChain, _callAddress, _payload, _extraArgs);
    }

    function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload)
        internal
        override
    {
        onCrossChainTransactionReceived(0, address(0), payload, "");
    }

    function _executeWithToken(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        bytes memory extraArgs = abi.encode(tokenSymbol, amount);
        onCrossChainTransactionReceived(0, address(0), payload, extraArgs);
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
