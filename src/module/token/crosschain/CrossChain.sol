// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

abstract contract CrossChain {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnCrossChainTransactionSentNotImplemented();
    error OnCrossChainTransactionReceivedNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    ) external payable virtual;

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
    ) internal virtual {
        revert OnCrossChainTransactionSentNotImplemented();
    }

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
        bytes memory _payload,
        bytes memory _extraArgs
    ) internal virtual {
        revert OnCrossChainTransactionReceivedNotImplemented();
    }

    function setRouter(address _router) external virtual;
    function getRouter() external view virtual returns (address);

}
