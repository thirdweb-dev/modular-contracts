// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";

library NonTransferableStorage {
    /// @custom:storage-location erc7201:non.transferable.storage
    bytes32 public constant NON_TRANSFERABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("non.transferable.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => whether transfers are disabled
        mapping(address => bool) transferDisabled;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = NON_TRANSFERABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract NonTransferableERC1155 is ModularExtension {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on attempt to transfer a token when transfers are disabled.
    error TransfersDisabled();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOKEN_ADMIN_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](3);

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC1155.selector, CallType.CALL);
        config.callbackFunctions[1] = CallbackFunction(this.beforeBatchTransferERC1155.selector, CallType.CALL);

        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.isTransfersDisabled.selector,
            callType: CallType.STATICCALL,
            permissionBits: 0
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.disableTransfers.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.enableTransfers.selector,
            callType: CallType.CALL,
            permissionBits: TOKEN_ADMIN_ROLE
        });

        config.requiredInterfaceId = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC1155.safeTransferFrom
    function beforeTransferERC1155(address, address, uint256, uint256) external virtual returns (bytes memory) {
        address token = msg.sender;
        if (_nonTransferableStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /// @notice Callback function for ERC1155.safeBatchTransferFrom
    function beforeBatchTransferERC1155(address, address, uint256[] calldata, uint256[] calldata)
        external
        virtual
        returns (bytes memory)
    {
        address token = msg.sender;
        if (_nonTransferableStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers are disabled for a token.
    function isTransfersDisabled(address _token) external view returns (bool) {
        return _nonTransferableStorage().transferDisabled[_token];
    }

    /// @notice Disables transfers for a token.
    function disableTransfers() external {
        address token = msg.sender;
        _nonTransferableStorage().transferDisabled[token] = true;
    }

    /// @notice Enables transfers for a token.
    function enableTransfers() external {
        address token = msg.sender;
        _nonTransferableStorage().transferDisabled[token] = false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _nonTransferableStorage() internal pure returns (NonTransferableStorage.Data storage) {
        return NonTransferableStorage.data();
    }
}
