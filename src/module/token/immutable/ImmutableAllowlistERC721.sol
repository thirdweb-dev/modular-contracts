// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";

import {
    OperatorAllowlistEnforced,
    OperatorAllowlistEnforcedStorage
} from "../../../../dependecies/immutable/allowlist/OperatorAllowlistEnforced.sol";
import {BeforeApproveCallbackERC721} from "../../../callback/BeforeApproveCallbackERC721.sol";
import {BeforeApproveForAllCallback} from "../../../callback/BeforeApproveForAllCallback.sol";
import {BeforeTransferCallbackERC721} from "../../../callback/BeforeTransferCallbackERC721.sol";

contract ImmutableAllowlistERC721 is
    Module,
    BeforeApproveCallbackERC721,
    BeforeApproveForAllCallback,
    BeforeTransferCallbackERC721,
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

        config.callbackFunctions[0] = CallbackFunction(this.beforeApproveERC721.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeApproveForAll.selector);
        config.callbackFunctions[2] = CallbackFunction(this.beforeTransferERC721.selector);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.setOperatorAllowlistRegistry.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.operatorAllowlist.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for ERC721.approve
    function beforeApproveERC721(address _from, address _to, uint256 _tokenId, bool _approve)
        external
        override
        validateApproval(_to)
        returns (bytes memory)
    {}

    /// @notice Callback function for ERC721.setApprovalForAll
    function beforeApproveForAll(address _from, address _to, bool _approved)
        external
        override
        validateApproval(_to)
        returns (bytes memory)
    {}

    /// @notice Callback function for ERC721.transferFrom/safeTransferFrom
    function beforeTransferERC721(address _from, address _to, uint256 _tokenId)
        external
        override
        validateTransfer(_from, _to)
        returns (bytes memory)
    {}

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address registry = abi.decode(data, (address));
        _setOperatorAllowlistRegistry(registry);
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
        _setOperatorAllowlistRegistry(newRegistry);
    }

}
