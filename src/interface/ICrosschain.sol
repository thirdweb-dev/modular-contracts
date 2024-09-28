// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ICrosschain {

    /**
     * @notice Sends a cross-chain transaction.
     * @param _destinationChain The destination chain ID.
     * @param _callAddress The address of the contract on the destination chain.
     * @param _payload The payload to send to the destination chain.
     * @param _extraArgs The extra arguments to pass
     * @dev extraArgs may contain items such as token, amount, feeTokenAddress, receipient, gasLimit, etc
     */
    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable;

    /**
     * @notice callback function for when a cross-chain transaction is sent.
     * @param _destinationChain The destination chain ID.
     * @param _callAddress The address of the contract on the destination chain.
     * @param _payload The payload sent to the destination chain.
     * @param _extraArgs The extra arguments sent to the callAddress on the destination chain.
     */
    function onCrossChainTransactionSent(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external;

    /**
     * @notice callback function for when a cross-chain transaction is received.
     * @param _sourceChain The source chain ID.
     * @param _sourceAddress The address of the contract on the source chain.
     * @param _payload The payload sent to the destination chain.
     * @param _extraArgs The extra arguments sent to the callAddress on the destination chain.
     */
    function onCrossChainTransactionReceived(
        uint64 _sourceChain,
        address _sourceAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external;

    function setRouter(address _router) external;
    function getRouter() external view returns (address);

}
