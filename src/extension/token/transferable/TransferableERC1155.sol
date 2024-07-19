// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";

import {BeforeBatchTransferCallbackERC1155} from "../../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../../callback/BeforeTransferCallbackERC1155.sol";

library TransferableStorage {

    /// @custom:storage-location erc7201:token.transferable
    bytes32 public constant TRANSFERABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.transferable")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // whether transfers are enabled
        bool transferEnabled;
        // from/to/operator address => bool, whether transfer is enabled
        mapping(address => bool) transferEnabledFor;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = TRANSFERABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract TransferableERC1155 is ModularExtension, BeforeTransferCallbackERC1155, BeforeBatchTransferCallbackERC1155 {

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
        config.callbackFunctions = new CallbackFunction[](2);
        config.fallbackFunctions = new FallbackFunction[](4);

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC1155.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeBatchTransferERC1155.selector);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.isTransferEnabled.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.isTransferEnabledFor.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.setTransferable.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setTransferableFor.selector, permissionBits: Role._MANAGER_ROLE});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC1155.safeTransferFrom
    function beforeTransferERC1155(address from, address to, uint256, uint256)
        external
        virtual
        override
        returns (bytes memory)
    {
        TransferableStorage.Data storage data = _transferableStorage();
        bool isOperatorAllowed =
            data.transferEnabledFor[msg.sender] || data.transferEnabledFor[from] || data.transferEnabledFor[to];

        if (!isOperatorAllowed && !data.transferEnabled) {
            revert TransferDisabled();
        }
    }

    /// @notice Callback function for ERC1155.safeBatchTransferFrom
    function beforeBatchTransferERC1155(address from, address to, uint256[] calldata, uint256[] calldata)
        external
        virtual
        override
        returns (bytes memory)
    {
        TransferableStorage.Data storage data = _transferableStorage();
        bool isOperatorAllowed =
            data.transferEnabledFor[msg.sender] || data.transferEnabledFor[from] || data.transferEnabledFor[to];

        if (!isOperatorAllowed && !data.transferEnabled) {
            revert TransferDisabled();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether transfers is enabled for the token.
    function isTransferEnabled() external view returns (bool) {
        return _transferableStorage().transferEnabled;
    }

    /// @notice Returns whether transfers is enabled for the target for the token.
    function isTransferEnabledFor(address target) external view returns (bool) {
        return _transferableStorage().transferEnabledFor[target];
    }

    /// @notice Set transferability for a token.
    function setTransferable(bool enableTransfer) external {
        _transferableStorage().transferEnabled = enableTransfer;
    }

    /// @notice Set transferability for an operator for a token.
    function setTransferableFor(address target, bool enableTransfer) external {
        _transferableStorage().transferEnabledFor[target] = enableTransfer;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transferableStorage() internal pure returns (TransferableStorage.Data storage) {
        return TransferableStorage.data();
    }

}
