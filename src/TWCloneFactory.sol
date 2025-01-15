// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {LibClone} from "@solady/utils/LibClone.sol";

contract TWCloneFactory {

    error ProxyDeploymentFailed();

    /// @dev Emitted when a proxy is deployed.
    event ProxyDeployed(
        address indexed implementation, address indexed proxy, address indexed deployer, bytes32 inputSalt, bytes data
    );

    /// @dev Deploys a proxy that points to the given implementation.
    function deployProxyByImplementation(address implementation, bytes memory data, bytes32 salt)
        public
        returns (address deployedProxy)
    {
        bytes32 saltHash = _guard(salt, data);
        deployedProxy = LibClone.cloneDeterministic(implementation, saltHash);

        emit ProxyDeployed(implementation, deployedProxy, msg.sender, salt, data);

        if (data.length > 0) {
            // slither-disable-next-line unused-return
            (bool success,) = deployedProxy.call(data);

            if (!success) {
                revert ProxyDeploymentFailed();
            }
        }
    }

    function _guard(bytes32 salt, bytes memory data) internal view returns (bytes32) {
        // 01 if cross chain deployment is allowed
        // 00 if cross chain deployment is not allowed
        bool allowCrossChainDeployment = bytes1(salt[0]) == hex"01";
        bool encodeDataIntoSalt = bytes1(salt[1]) == hex"01";

        if (allowCrossChainDeployment && encodeDataIntoSalt) {
            return keccak256(abi.encode(salt, data));
        } else if (allowCrossChainDeployment && !encodeDataIntoSalt) {
            return salt;
        } else if (!allowCrossChainDeployment && encodeDataIntoSalt) {
            return keccak256(abi.encode(salt, block.chainid, data));
        } else {
            return keccak256(abi.encode(salt, block.chainid));
        }
    }

}
