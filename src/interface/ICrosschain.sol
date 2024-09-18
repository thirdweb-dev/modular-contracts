// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ICrosschain {

    /**
     * @notice Sends a cross-chain payload.
     * @param _destinationChain The destination chain ID.
     * @param _callAddress The address of the contract on the destination chain.
     * @param _payload The payload to send to the destination chain.
     * @param _extraArgs The extra arguments to pass
     * @dev extraArgs may contain items such as feeTokenAddress, receipient, gasLimit, etc
     * @dev uint64 since that is the upper range used by the protocols (ie: chainlink)
     */
    function sendCrossChainPayload(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable;

    /**
     * @notice Sends a cross-chain payload with a token transfer.
     * @param _destinationChain The destination chain ID.
     * @param _callAddress The address of the contract on the destination chain.
     * @param _token The token address.
     * @param _amount The amount of tokens to transfer.
     * @param _payload The payload to send to the destination chain.
     * @param _extraArgs The extra arguments to pass to the callAddress on the destination chain.
     * @dev extraArgs may contain items such as feeTokenAddress, receipient, gasLimit, etc
     * @dev uint64 since that is the upper range used by the protocols (ie: chainlink)
     */
    function sendCrossChainPayloadWithToken(
        uint64 _destinationChain,
        address _callAddress,
        address _token,
        uint256 _amount,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external payable;

    /**
     * @notice callback function for when a cross-chain payload is sent.
     * @param _destinationChain The destination chain ID.
     * @param _callAddress The address of the contract on the destination chain.
     * @param _payload The payload sent to the destination chain.
     * @param _extraArgs The extra arguments sent to the callAddress on the destination chain.
     */
    function onMessageSent(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external;

    /**
     * @notice callback function for when a cross-chain payload is received.
     * @param _sourceChain The source chain ID.
     * @param _sourceAddress The address of the contract on the source chain.
     * @param _payload The payload sent to the destination chain.
     * @param _extraArgs The extra arguments sent to the callAddress on the destination chain.
     */
    function onMessageReceived(
        uint64 _sourceChain,
        address _sourceAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) external;

    function setRouter(address _router) external;
    function getRouter(address _router) external view returns (address);

}
