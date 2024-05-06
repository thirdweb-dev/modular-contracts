// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

// ERC1967 Proxy
contract ExtensionProxy {
    event Upgraded(address indexed implementation);

    error InvalidAddress();
    error InvalidContract();
    error UpgradeCallFailed();

    /// @dev The ERC-1967 storage slot for the implementation in the proxy.
    /// `uint256(keccak256("eip1967.proxy.implementation")) - 1`.
    bytes32 private constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The ERC-1967 storage slot for the admin in the proxy.
    /// `uint256(keccak256("eip1967.proxy.admin")) - 1`.
    bytes32 private constant _ERC1967_ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address implementation) {
        _setAdmin(msg.sender);
        _setImplementation(implementation);
    }

    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }

        assembly {
            sstore(_ERC1967_ADMIN_SLOT, newAdmin)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert InvalidContract();
        }
        assembly {
            sstore(_ERC1967_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0 || forceCall) {
            (bool success, bytes memory returndata) = newImplementation
                .delegatecall(data);
            if (!success) {
                _revert(returndata, UpgradeCallFailed.selector);
            }
        }
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory returnData, bytes4 errorSignature)
        internal
        pure
    {
        // Look for revert reason and bubble it up if present
        if (returnData.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(0x20, returnData), mload(returnData))
            }
        } else {
            assembly {
                mstore(0x00, errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    function _fallback() internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(
                gas(),
                sload(_ERC1967_IMPLEMENTATION_SLOT),
                0,
                calldatasize(),
                0,
                0
            )

            returndatacopy(0, 0, returndatasize())
            if iszero(result) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
