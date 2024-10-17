// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ICrossChainERC20} from "src/module/token/crosschain/SuperChainInterop.sol";
import {IL2ToL2CrossDomainMessenger} from "./IL2ToL2CrossDomainMessenger.sol";
import "lib/forge-std/src/console.sol";

contract SuperChainBridge {

    address public immutable MESSENGER;

    event SentERC20(address indexed _token, address indexed, address indexed _to, uint256 _amount, uint256 _chainId);
    event RelayedERC20(
        address indexed _token, address indexed _from, address indexed _to, uint256 _amount, uint256 _source
    );

    constructor(address _L2ToL2CrossDomainMesenger) {
        MESSENGER = _L2ToL2CrossDomainMesenger;
    }

    function sendERC20(address _token, address _to, uint256 _amount, uint256 _chainId)
        external
        returns (bytes32 msgHash_)
    {
        ICrossChainERC20(_token).crosschainBurn(msg.sender, _amount);

        bytes memory _message = abi.encodeCall(this.relayERC20, (_token, msg.sender, _to, _amount));
        msgHash_ = IL2ToL2CrossDomainMessenger(MESSENGER).sendMessage(_chainId, address(this), _message);
        console.log("message sent");

        emit SentERC20(address(_token), msg.sender, _to, _amount, _chainId);
    }

    function relayERC20(address _token, address _from, address _to, uint256 _amount) external {
        require(msg.sender == MESSENGER);
        require(IL2ToL2CrossDomainMessenger(MESSENGER).crossDomainMessageSender() == address(this));

        uint256 _source = IL2ToL2CrossDomainMessenger(MESSENGER).crossDomainMessageSource();
        console.log("message received");

        ICrossChainERC20(_token).crosschainMint(_to, _amount);

        emit RelayedERC20(address(_token), _from, _to, _amount, _source);
    }

}
