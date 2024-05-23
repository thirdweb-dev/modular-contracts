// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";

library TransferableStorage {
    /// @custom:storage-location erc7201:token.transferable
    bytes32 public constant TRANSFERABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.transferable")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => whether transfers are enabled
        mapping(address => bool) transferEnabled;
        // token => from/to/operator address => bool, whether transfer is enabled
        mapping(address => mapping(address => bool)) transferrerAllowed;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = TRANSFERABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract TransferableERC20 is ModularExtension {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on attempt to transfer a token when transfers are disabled.
    error TransferDisabled();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC20.selector, CallType.CALL);

        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.isTransferEnabled.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.isTransferEnabledFor.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.setTransferable.selector,
            callType: CallType.CALL,
            permissionBits: Role._MANAGER_ROLE
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setTransferableFor.selector,
            callType: CallType.CALL,
            permissionBits: Role._MANAGER_ROLE
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC20.transfer
    function beforeTransferERC20(address from, address to, uint256) external virtual returns (bytes memory) {
        address token = msg.sender;
        TransferableStorage.Data storage data = _transferableStorage();
        bool isOperatorAllowed = data.transferrerAllowed[token][from] || data.transferrerAllowed[token][to];

        if (!isOperatorAllowed && !data.transferEnabled[token]) {
            revert TransferDisabled();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers is enabled for the token.
    function isTransferEnabled() external view returns (bool) {
        return _transferableStorage().transferEnabled[msg.sender];
    }

    /// @notice Returns whether transfers is enabled for the transferrer for the token.
    function isTransferEnabledFor(address transferrer) external view returns (bool) {
        return _transferableStorage().transferrerAllowed[msg.sender][transferrer];
    }

    /// @notice Set transferability for a token.
    function setTransferable(bool enableTransfer) external {
        address token = msg.sender;
        _transferableStorage().transferEnabled[token] = enableTransfer;
    }

    /// @notice Set transferability for an operator for a token.
    function setTransferableFor(address transferrer, bool enableTransfer) external {
        address token = msg.sender;
        _transferableStorage().transferrerAllowed[token][transferrer] = enableTransfer;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transferableStorage() internal pure returns (TransferableStorage.Data storage) {
        return TransferableStorage.data();
    }
}
