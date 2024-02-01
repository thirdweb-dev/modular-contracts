// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/LibClone.sol";

contract CloneFactory {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a clone is deployed.
    event ProxyDeployed(address indexed implementation, address proxy, address indexed deployer);

    /*//////////////////////////////////////////////////////////////
                                ERROR
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on failure to initialize clone.
    error CloneFactoryFailedToInitialize();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Deploys a minimal clone at a determininstic address.
     *  @param _implementation The implementation to point a clone to.
     *  @param _data The data to initialize the clone with.
     *  @param _salt The salt to use for the deployment of the clone.
     */
    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public returns (address deployedProxy) {
        bytes32 salthash = keccak256(abi.encodePacked(msg.sender, _salt));
        deployedProxy = LibClone.cloneDeterministic(_implementation, salthash);

        emit ProxyDeployed(_implementation, deployedProxy, msg.sender);

        if (_data.length > 0) {
            (bool success, bytes memory returndata) = deployedProxy.call(_data);

            if (!success) {
                _revert(returndata);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory _returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (_returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(_returndata)
                revert(add(32, _returndata), returndata_size)
            }
        } else {
            revert CloneFactoryFailedToInitialize();
        }
    }
}
