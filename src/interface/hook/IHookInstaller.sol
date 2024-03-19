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
     *  @param initCallValue The value to send with the initialization call.
     *  @param initCalldata The calldata to send with the initialization call.
     */
    struct InstallHookParams {
        IHook hook;
        uint256 initCallValue;
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
     */
    struct HookFallbackFunctionCall {
        address target;
        CallType callType;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a hook is installed.
    event HooksInstalled(address indexed implementation, uint256 hooks);

    /// @notice Emitted when a hook is uninstalled.
    event HooksUninstalled(uint256 hooks);

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
     *  @dev Unlike `installHook`, we do not accept a hook contract address as a parameter since it is possible
     *       that the hook contract returns different hook functions compared to when it was installed. This could
     *       lead to a mismatch. Instead, we use the bit representation of the hooks to uninstall.
     *  @param hooksToUninstall The bit representation of the hooks to uninstall.
     */
    function uninstallHook(uint256 hooksToUninstall) external;
}
