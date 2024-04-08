// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "./IHook.sol";
import {IHookInfo} from "./IHookInfo.sol";

interface IHookInstaller is IHookInfo {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Parameters for installing a hook.
     *
     *  @param hook The hook to install.
     *  @param initValue The value to send with the initialization call.
     *  @param initCalldata The calldata to send with the initialization call.
     */
    struct InstallHookParams {
        address hook;
        uint256 initValue;
        bytes initCalldata;
    }

    /**
     *  @notice Parameters for any external call to make on initializing a core contract.
     *
     *  @param target The address of the contract to call.
     *  @param value The value to send with the call.
     *  @param data The calldata to send with the call.
     */
    struct OnInitializeParams {
        address target;
        uint256 value;
        bytes data;
    }

    /**
     *  @notice Parameters for a hook contract call to make inside the fallback function.
     *  @param target The address of the contract to call.
     *  @param callType The type of call to make.
     *  @param permissioned Whether the call requires permission on the core contract.
     */
    struct HookFallbackFunctionCall {
        address target;
        CallType callType;
        bool permissioned;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is installed.
    event HooksInstalled(address indexed implementation, uint256 hooks);

    /// @notice Emitted when a hook is uninstalled.
    event HooksUninstalled(address indexed implementation, uint256 hooks);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the implementation of a given hook, if any.
     *  @param flag The bits representing the hook.
     *  @return impl The implementation of the hook.
     */
    function getHookImplementation(uint256 flag) external view returns (address impl);

    /**
     *  @notice Returns the call destination of a hook fallback function.
     *  @param _selector The selector of the function.
     *  @return target The fallback function call info including the target address, function selector, and call type.
     */
    function getHookFallbackFunctionCall(bytes4 _selector) external view returns (HookFallbackFunctionCall memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param _params The parameters for installing the hook and initializing it with some data.
     */
    function installHook(InstallHookParams memory _params) external payable;

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @param _hook The contract whose implemented hooks are to be uninstalled.
     */
    function uninstallHook(address _hook) external;
}
