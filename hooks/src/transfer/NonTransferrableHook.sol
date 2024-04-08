// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IHook} from "@core-contracts/interface/IHook.sol";

import {HookFlagsDirectory} from "@core-contracts/hook/HookFlagsDirectory.sol";
import {BeforeTransferHookERC20} from "@core-contracts/hook/BeforeTransferHookERC20.sol";
import {BeforeTransferHookERC721} from "@core-contracts/hook/BeforeTransferHookERC721.sol";
import {BeforeTransferHookERC1155} from "@core-contracts/hook/BeforeTransferHookERC1155.sol";
import {BeforeBatchTransferHookERC1155} from "@core-contracts/hook/BeforeBatchTransferHookERC1155.sol";

import {Multicallable} from "@solady/utils/Multicallable.sol";

library NonTransferableHookStorage {
    /// @custom:storage-location erc7201:non.transferable.hook.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("non.transferable.hook.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant NON_TRANSFERABLE_HOOK_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("non.transferable.hook.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(address => bool) transferDisabled;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = NON_TRANSFERABLE_HOOK_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract NonTransferableHook is
    IHook,
    BeforeTransferHookERC20,
    BeforeTransferHookERC721,
    BeforeTransferHookERC1155,
    BeforeBatchTransferHookERC1155
{
    /*//////////////////////////////////////////////////////////////
    CONSTANTS: (TODO: replace with inheriting HooksFlagDirectory)
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the beforeTransferERC20 hook.
    uint256 public constant BEFORE_TRANSFER_ERC20_FLAG = 2 ** 11;

    /// @notice Bits representing the beforeTransferERC1155 hook.
    uint256 public constant BEFORE_TRANSFER_ERC1155_FLAG = 2 ** 13;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TransfersDisabled();

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHookInfo() external pure returns (HookInfo memory info) {
        info.hookFlags = BEFORE_TRANSFER_ERC20_FLAG | BEFORE_TRANSFER_ERC721_FLAG | BEFORE_TRANSFER_ERC1155_FLAG;
        info.hookFallbackFunctions[0] =
            HookFallbackFunction(this.isTransfersDisabled.selector, CallType.STATICCALL, false);
        info.hookFallbackFunctions[1] = HookFallbackFunction(this.disableTransfers.selector, CallType.CALL, false);
        info.hookFallbackFunctions[2] = HookFallbackFunction(this.enableTransfers.selector, CallType.CALL, false);
    }

    function beforeTransferERC20(address, address, uint256) external virtual override returns (bytes memory) {
        address token = msg.sender;
        if (_nonTransferableHookStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    function beforeTransferERC721(address, address, uint256) external virtual override returns (bytes memory) {
        address token = msg.sender;
        if (_nonTransferableHookStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    function beforeTransferERC1155(address, address, uint256, uint256)
        external
        virtual
        override
        returns (bytes memory result)
    {
        address token = msg.sender;
        if (_nonTransferableHookStorage().transferDisabled[token]) {
            revert TransfersDisabled();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isTransfersDisabled(address _token) external view returns (bool) {
        return _nonTransferableHookStorage().transferDisabled[_token];
    }

    function disableTransfers() external {
        address token = msg.sender;
        _nonTransferableHookStorage().transferDisabled[token] = true;
    }

    function enableTransfers() external {
        address token = msg.sender;
        _nonTransferableHookStorage().transferDisabled[token] = false;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _nonTransferableHookStorage() internal pure returns (NonTransferableHookStorage.Data storage) {
        return NonTransferableHookStorage.data();
    }
}
