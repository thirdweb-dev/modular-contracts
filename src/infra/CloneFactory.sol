// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/Clones.sol";

contract CloneFactory {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProxyDeployed(address indexed implementation, address proxy, address indexed deployer);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deployProxyByImplementation(address _implementation, bytes memory _data, bytes32 _salt)
        public
        returns (address deployedProxy)
    {
        bytes32 salthash = keccak256(abi.encodePacked(msg.sender, _salt));
        deployedProxy = Clones.cloneDeterministic(_implementation, salthash);

        emit ProxyDeployed(_implementation, deployedProxy, msg.sender);

        if (_data.length > 0) {
            (bool success, bytes memory returndata) = deployedProxy.call(_data);

            if (!success) {
                _revert(returndata, "Failed to initialize proxy");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _revert(bytes memory _returndata, string memory _errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (_returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(_returndata)
                revert(add(32, _returndata), returndata_size)
            }
        } else {
            revert(_errorMessage);
        }
    }
}
