// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ICrosschain {

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _extraArgs
    ) external;

}
