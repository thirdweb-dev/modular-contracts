// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/Clones.sol";
import "../lib/Address.sol";

contract CloneFactory {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProxyDeployed(address indexed implementation, address proxy, address indexed deployer);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public returns (address deployedProxy) {
        bytes32 salthash = keccak256(abi.encodePacked(msg.sender, _salt));
        deployedProxy = Clones.cloneDeterministic(_implementation, salthash);

        emit ProxyDeployed(_implementation, deployedProxy, msg.sender);

        if (_data.length > 0) {
            // slither-disable-next-line unused-return
            Address.functionCall(deployedProxy, _data);
        }
    }
}