// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "@solady/utils/LibBitmap.sol";
import {LibBit} from "@solady/utils/LibBit.sol";

import {IHook} from "../interface/hook/IHook.sol";
import {IHookInstaller} from "../interface/hook/IHookInstaller.sol";

abstract contract HookInstaller is IHookInstaller {
    using LibBitmap for LibBitmap.Bitmap;
    using LibBit for uint256;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing all hooks installed.
    uint256 private installedHooks_;

    /// @notice Whether a given hook is installed in the contract.
    LibBitmap.Bitmap private hookImplementations_;

    /// @notice Mapping from hook bits representation => implementation of the hook.
    mapping(uint256 => address) private hookImplementationMap_;

    /// @notice Mapping from bytes4 function selector => hook contract.
    mapping(bytes4 => address) private hookFallbackFunctionMap_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the caller is not authorized to install/uninstall hooks.
    error HookInstallerNotAuthorized();

    /// @notice Emitted on failure to perform a call to a hook contract.
    error HookInstallerHookCallFailed();

    /// @notice Emitted when the caller attempts to write to a hook contract without permission.
    error HookInstallerUnauthorizedWrite();

    /// @notice Emitted when the caller attempts to install a hook that is already installed.
    error HookInstallerHookAlreadyInstalled();

    /// @notice Emitted on attempt to call an uninstalled hook.
    error HookInstallerHookNotInstalled();

    /// @notice Emitted on installing a hook that is incompatible with the hook installer.
    error HookInstallerIncompatibleHook();

    /// @notice Emitted when installing or uninstalling the zero address as a hook.
    error HookInstallerZeroAddress();

    /// @notice Emitted on attempt to initialize a hook with invalid msg.value.
    error HookInstallerInvalidMsgValue();

    /// @notice Emitted when the caller attempts to call a non-existent hook fallback function.
    error HookInstallerFallbackFunctionDoesNotExist();

    /// @notice Emitted on attempt to overwrite an in-use hook fallback function.
    error HookInstallerHookFallbackFunctionUsed(bytes4 functionSelector);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Retusn the implementation of a given hook, if any.
     *  @param _flag The bits representing the hook.
     *  @return impl The implementation of the hook.
     */
    function getHookImplementation(uint256 _flag) public view returns (address) {
        return hookImplementationMap_[_flag];
    }

    /**
     *  @notice Returns the call destination of a hook fallback function.
     *  @param _selector The selector of the function.
     *  @return target The address of the call destination.
     */
    function getHookFallbackFunctionTarget(bytes4 _selector) external view returns (address) {
        return hookFallbackFunctionMap_[_selector];
    }

    /*//////////////////////////////////////////////////////////////
                        FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    fallback() external payable {
        if (!_canWriteToHooks(msg.sender)) {
            revert HookInstallerUnauthorizedWrite();
        }

        address target = hookFallbackFunctionMap_[msg.sig];
        if (target == address(0)) {
            revert HookInstallerFallbackFunctionDoesNotExist();
        }

        (bool success, bytes memory returndata) = target.call{value: msg.value}(msg.data);
        if (!success) {
            _revert(returndata, HookInstallerHookCallFailed.selector);
        }
    }

    receive() external payable virtual {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param _params The parameters for installing a hook and initializing it with some data.
     */
    function installHook(InstallHookParams memory _params) external payable {
        // Validate the caller's permissions.
        if (!_canUpdateHooks(msg.sender)) {
            revert HookInstallerNotAuthorized();
        }
        // Validate init calldata and value
        if (_params.initCallValue != msg.value) {
            revert HookInstallerInvalidMsgValue();
        }
        _installHook(_params);
    }

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param _hook The hook to uninstall.
     */
    function uninstallHook(IHook _hook) external {
        // Validate the caller's permissions.
        if (!_canUpdateHooks(msg.sender)) {
            revert HookInstallerNotAuthorized();
        }

        // Validate hook address.
        if (address(_hook) == address(0)) {
            revert HookInstallerZeroAddress();
        }
        if (!hookImplementations_.get(uint160(address(_hook)))) {
            revert HookInstallerHookNotInstalled();
        }

        // Get the flags of all the hook functions for which to remove the hook contract
        // as their implementation.
        uint256 hooksToUninstall = _hook.getHooks();

        // 1. For each hook function i.e. flag <= 2 ** _maxHookFlag(): If the installed hook contract
        //    implements the hook function, delete it as the implementation of the hook function.
        //
        // 2. Update the tracked installed hooks of the contract.
        uint256 currentActivehooks = installedHooks_;
        uint256 flag = 2 ** _maxHookFlag();
        while (flag > 1) {
            if (hooksToUninstall & flag > 0) {
                currentActivehooks &= ~flag;
                delete hookImplementationMap_[flag];
            }
            flag >>= 1;
        }
        installedHooks_ = currentActivehooks;

        // Get all the hook fallback functions and delete the hook contract
        // as their call destination.
        bytes4[] memory selectors = _hook.getHookFallbackFunctions();
        for (uint256 i = 0; i < selectors.length; i++) {
            delete hookFallbackFunctionMap_[selectors[i]];
        }

        emit HooksUninstalled(address(_hook), hooksToUninstall);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Installs a hook in the contract. We extract this logic in an internal function to allow
     *       re-use inside a contract constructor / initializer to isntall hooks during contract creation.
     */
    function _installHook(InstallHookParams memory _params) internal {
        // Validate hook address.
        if (address(_params.hook) == address(0)) {
            revert HookInstallerZeroAddress();
        }
        if (hookImplementations_.get(uint160(address(_params.hook)))) {
            revert HookInstallerHookAlreadyInstalled();
        }

        // Store hook as installed.
        hookImplementations_.set(uint160(address(_params.hook)));

        // Get flags of all the hook functions for which to set the hook contract
        // as their implementation.
        uint256 hooksToInstall = _params.hook.getHooks();

        // Validate the hook is compatible with the hook installer.
        uint256 flag = 2 ** _maxHookFlag();
        if (flag < _highestBitToZero(hooksToInstall)) {
            revert HookInstallerIncompatibleHook();
        }

        // 1. For each hook function i.e. flag <= 2 ** _maxHookFlag(): If the installed hook contract
        //    implements the hook function, set it as the implementation of the hook function.
        //
        // 2. Update the tracked installed hooks of the contract.
        uint256 currentActivehooks = installedHooks_;
        while (flag > 1) {
            if (hooksToInstall & flag > 0) {
                if (currentActivehooks & flag > 0) {
                    revert HookInstallerHookAlreadyInstalled();
                }
                currentActivehooks |= flag;
                hookImplementationMap_[flag] = address(_params.hook);
            }
            flag >>= 1;
        }
        installedHooks_ = currentActivehooks;

        // Get all the hook fallback functions and map them to the hook contract
        // as their call destination.
        bytes4[] memory selectors = _params.hook.getHookFallbackFunctions();
        for (uint256 i = 0; i < selectors.length; i++) {
            if (hookFallbackFunctionMap_[selectors[i]] != address(0)) {
                revert HookInstallerHookFallbackFunctionUsed(selectors[i]);
            }

            hookFallbackFunctionMap_[selectors[i]] = address(_params.hook);
        }

        // Finally, initialize the hook with the given calldata and value.
        if (_params.initCalldata.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) =
                address(_params.hook).call{value: _params.initCallValue}(_params.initCalldata);
            if (!success) {
                _revert(returndata, HookInstallerHookCallFailed.selector);
            }
        }

        emit HooksInstalled(address(_params.hook), hooksToInstall);
    }

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view virtual returns (bool);

    /// @dev Returns whether the caller can write to hook contracts via the fallback function.
    function _canWriteToHooks(address _caller) internal view virtual returns (bool);

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure virtual returns (uint8) {
        return 0;
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory _returndata, bytes4 _errorSignature) internal pure {
        // Look for revert reason and bubble it up if present
        if (_returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(_returndata)
                revert(add(32, _returndata), returndata_size)
            }
        } else {
            assembly {
                mstore(0x00, _errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }

    function _highestBitToZero(uint256 _value) public pure returns (uint256) {
        if (_value == 0) return 0; // Handle edge case where value is 0
        uint256 index = _value.fls(); // Find the index of the MSB
        return (1 << index); // Shift 1 left by the index of the MSB
    }
}
