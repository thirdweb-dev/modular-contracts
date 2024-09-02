// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";

import {BeforeApproveForAllCallback} from "../../../callback/BeforeApproveForAllCallback.sol";

import {BeforeBatchTransferCallbackERC1155} from "../../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../../callback/BeforeTransferCallbackERC1155.sol";
import {OperatorAllowlistEnforced} from "@imtbl/contracts/allowlist/OperatorAllowlistEnforced.sol";

library ImmutableAllowlistStorage {

    /// @custom:storage-location erc7201:token.immutableallowlist
    bytes32 public constant IMMUTABLE_ALLOWLIST_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.immutableAllowlist.ERC1155")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address operatorAllowlistRegistry;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = IMMUTABLE_ALLOWLIST_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract ImmutableAllowlistERC1155 is
    Module,
    BeforeApproveForAllCallback,
    BeforeTransferCallbackERC1155,
    BeforeBatchTransferCallbackERC1155,
    OperatorAllowlistEnforced
{

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an unauthorized approval is attempted.
    error OperatorAllowlistUnauthorizedApproval(address operator);

    /// @notice Emitted when an unauthorized transfer is attempted.
    error OperatorAllowlistUnauthorizedTransfer(address from, address to, address operator);

    /// @notice Emitted when the operator allowlist is not set.
    error OperatorAllowlistNotSet();

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](3);
        config.fallbackFunctions = new FallbackFunction[](2);

        config.callbackFunctions[1] = CallbackFunction(this.beforeApproveForAll.selector);
        config.callbackFunctions[2] = CallbackFunction(this.beforeTransferERC1155.selector);
        config.callbackFunctions[3] = CallbackFunction(this.beforeBatchTransferERC1155.selector);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setOperatorAllowlistRegistry.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.getOperatorAllowlistRegistry.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC1155

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isOperatorAllowlistSet() {
        if (_immutableAllowlistStorage().operatorAllowlistRegistry == address(0)) {
            revert OperatorAllowlistNotSet();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC1155.setApprovalForAll
    function beforeApproveForAll(address _from, address _to, bool _approved)
        external
        override
        isOperatorAllowlistSet
        validateApproval(_to)
        returns (bytes memory)
    {}

    /// @notice Callback function for ERC1155.transferFrom/safeTransferFrom
    function beforeTransferERC1155(address _from, address _to, uint256 _id, uint256 _value)
        external
        override
        isOperatorAllowlistSet
        validateTransfer(_from, _to)
        returns (bytes memory)
    {}

    /// @notice Callback function for ERC1155.transferFrom/safeTransferFrom
    function beforeBatchTransferERC1155(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values)
        external
        override
        isOperatorAllowlistSet
        validateTransfer(_from, _to)
        returns (bytes memory)
    {}

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address registry = abi.decode(data, (address));
        _immutableAllowlistStorage().operatorAllowlistRegistry = registry;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address operatorAllowlistRegistry) external pure returns (bytes memory) {
        return abi.encode(operatorAllowlistRegistry);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the operator allowlist registry address
    function setOperatorAllowlistRegistry(address newRegistry) external {
        _immutableAllowlistStorage().operatorAllowlistRegistry = newRegistry;
    }

    /// @notice Get the current operator allowlist registry address
    function getOperatorAllowlistRegistry() external view returns (address) {
        return _immutableAllowlistStorage().operatorAllowlistRegistry;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _immutableAllowlistStorage() internal pure returns (ImmutableAllowlistStorage.Data storage) {
        return ImmutableAllowlistStorage.data();
    }

}
