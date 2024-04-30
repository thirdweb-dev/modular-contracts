// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";

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

contract NonTransferable is IExtensionContract {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on attempt to transfer a token when transfers are disabled.
    error TransfersDisabled();

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and extension functions.
    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](3);
        config.extensionABI = new ExtensionFunction[](3);

        config.callbackFunctions[0] = this.beforeTransferERC20.selector;
        config.callbackFunctions[1] = this.beforeTransferERC721.selector;
        config.callbackFunctions[2] = this.beforeTransferERC1155.selector;

        config.extensionABI[0] = ExtensionFunction({
            selector: this.isTransfersDisabled.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[1] =
            ExtensionFunction({selector: this.disableTransfers.selector, callType: CallType.CALL, permissioned: true});
        config.extensionABI[2] =
            ExtensionFunction({selector: this.enableTransfers.selector, callType: CallType.CALL, permissioned: true});
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC20.transfer
    function beforeTransferERC20(address, address, uint256) external virtual returns (bytes memory) {
        address token = msg.sender;
        if (_nonTransferableStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /// @notice Callback function for ERC721.transferFrom/safeTransferFrom
    function beforeTransferERC721(address, address, uint256) external virtual returns (bytes memory) {
        address token = msg.sender;
        if (_nonTransferableStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /// @notice Callback function for ERC1155.safeTransferFrom
    function beforeTransferERC1155(address, address, uint256, uint256) external virtual returns (bytes memory result) {
        address token = msg.sender;
        if (_nonTransferableStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
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
