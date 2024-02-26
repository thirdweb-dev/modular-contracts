// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author thirdweb

contract EIP1967Proxy {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The ERC-1967 storage slot for the implementation of the proxy: bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AddressSlot {
        address value;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on failure to initialize proxy.
    error EIP1967ProxyFailedToInitialize();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    event Suucc(bool success);

    constructor(address _implementationAddress, bytes memory _initializeData) payable {
        _getImplementationSlot().value = _implementationAddress;

        if (_initializeData.length > 0) {
            // slither-disable-next-line unused-return
            (bool success, bytes memory returndata) = _implementationAddress.delegatecall(_initializeData);

            if (!success) {
                _revert(returndata);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function that delegates calls to the address returned by `_implementation()`.
    fallback() external payable virtual {
        _delegate(_getImplementationSlot().value);
    }

    /// @notice Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data is empty.
    receive() external payable virtual {
        _delegate(_getImplementationSlot().value);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the ERC-1967 storage slot for the implementation of the proxy.
    function _getImplementationSlot() internal pure returns (AddressSlot storage s) {
        assembly {
            s.slot := _IMPLEMENTATION_SLOT
        }
    }

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
            revert EIP1967ProxyFailedToInitialize();
        }
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
