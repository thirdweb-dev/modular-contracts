// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ModularExtension} from "../../../ModularExtension.sol";
import {Role} from "../../../Role.sol";
import {BeforeTransferCallbackERC1155} from "../../../callback/BeforeTransferCallbackERC1155.sol";
import {BeforeBatchTransferCallbackERC1155} from "../../../callback/BeforeBatchTransferCallbackERC1155.sol";

library TransferableStorage {
    /// @custom:storage-location erc7201:token.transferable
    bytes32 public constant TRANSFERABLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.transferable")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        // token => whether transfers are enabled
        mapping(address => bool) transferEnabled;
        // token => from/to/operator address => bool, whether transfer is enabled
        mapping(address => mapping(address => bool)) transferEnabledFor;
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

        config.callbackFunctions[0] = CallbackFunction(this.beforeTransferERC1155.selector, CallType.CALL);
        config.callbackFunctions[1] = CallbackFunction(this.beforeBatchTransferERC1155.selector, CallType.CALL);

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

        config.requiredInterfaceId = 0xd9b67a26; // ERC1155
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC1155.safeTransferFrom
    function beforeTransferERC1155(address caller, address from, address to, uint256, uint256)
        external
        virtual
        override
        returns (bytes memory)
    {
        address token = msg.sender;
        TransferableStorage.Data storage data = _transferableStorage();
        bool isOperatorAllowed = data.transferEnabledFor[token][caller] || data.transferEnabledFor[token][from]
            || data.transferEnabledFor[token][to];

        if (!isOperatorAllowed && !data.transferEnabled[token]) {
            revert TransferDisabled();
        }
    }

    /// @notice Callback function for ERC1155.safeBatchTransferFrom
    function beforeBatchTransferERC1155(
        address caller,
        address from,
        address to,
        uint256[] calldata,
        uint256[] calldata
    ) external virtual override returns (bytes memory) {
        address token = msg.sender;
        TransferableStorage.Data storage data = _transferableStorage();
        bool isOperatorAllowed = data.transferEnabledFor[token][caller] || data.transferEnabledFor[token][from]
            || data.transferEnabledFor[token][to];

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

    /// @notice Returns whether transfers is enabled for the target for the token.
    function isTransferEnabledFor(address target) external view returns (bool) {
        return _transferableStorage().transferEnabledFor[msg.sender][target];
    }

    /// @notice Set transferability for a token.
    function setTransferable(bool enableTransfer) external {
        address token = msg.sender;
        _transferableStorage().transferEnabled[token] = enableTransfer;
    }

    /// @notice Set transferability for an operator for a token.
    function setTransferableFor(address target, bool enableTransfer) external {
        address token = msg.sender;
        _transferableStorage().transferEnabledFor[token][target] = enableTransfer;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _transferableStorage() internal pure returns (TransferableStorage.Data storage) {
        return TransferableStorage.data();
    }
}
