// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "@solady/utils/LibBitmap.sol";

import {IHook} from "../interface/hook/IHook.sol";
import {IHookInstaller} from "../interface/hook/IHookInstaller.sol";

abstract contract HookInstaller is IHookInstaller {
    using LibBitmap for LibBitmap.Bitmap;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing all hooks installed.
    uint256 private installedHooks_;

    /// @notice Whether a given hook is installed in the contract.
    LibBitmap.Bitmap private hookImplementations_;

    /// @notice Mapping from hook bits representation => implementation of the hook.
    mapping(uint256 => address) private hookImplementationMap_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the caller is not authorized to install/uninstall hooks.
    error HookInstallerNotAuthorized();

    /// @notice Emitted on failure to perform a call to a hook contract.
    error HookInstallerHookCallFailed();

    /// @notice Emitted on attempt to call a non-existent hook.
    error HookInstallerInvalidHook();

    /// @notice Emitted when the caller attempts to install a hook that is already installed.
    error HookInstallerHookAlreadyInstalled();

    /// @notice Emitted on attempt to call an uninstalled hook.
    error HookInstallerHookNotInstalled();

    /// @notice Emitted on attempt to write to hooks without permission.
    error HookInstallerUnauthorizedWrite();

    /// @notice Emitted on attempt to initialize a hook with invalid msg.value.
    error HookInstallerInvalidMsgValue();

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
     *  @notice A generic entrypoint to read state of any of the installed hooks.
     *  @param _hookFlag The bits representing the hook.
     *  @param _data The data to pass to the hook staticcall.
     *  @return returndata The return data from the hook view function call.
     */
    function hookFunctionRead(uint256 _hookFlag, bytes calldata _data) external view returns (bytes memory) {
        if (_hookFlag > 2 ** _maxHookFlag()) {
            revert HookInstallerInvalidHook();
        }

        address target = getHookImplementation(_hookFlag);
        if (target == address(0)) {
            revert HookInstallerHookNotInstalled();
        }

        (bool success, bytes memory returndata) = target.staticcall(_data);
        if (!success) {
            _revert(returndata, HookInstallerHookCallFailed.selector);
        }
        return returndata;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param _params The parameters for installing a hook and initializing it with some data.
     */
    function installHook(InstallHookParams memory _params) external payable {
        if (!_canUpdateHooks(msg.sender)) {
            revert HookInstallerNotAuthorized();
        }
        if (address(_params.hook) == address(0)) {
            revert HookInstallerInvalidHook();
        }
        if (_params.initCallValue != msg.value) {
            revert HookInstallerInvalidMsgValue();
        }

        _installHook(_params.hook);

        if (_params.initCalldata.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) =
                address(_params.hook).call{value: _params.initCallValue}(_params.initCalldata);
            if (!success) {
                _revert(returndata, HookInstallerHookCallFailed.selector);
            }
        }
    }

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param _hook The hook to uninstall.
     */
    function uninstallHook(IHook _hook) external {
        if (!_canUpdateHooks(msg.sender)) {
            revert HookInstallerNotAuthorized();
        }
        if (address(_hook) == address(0)) {
            revert HookInstallerInvalidHook();
        }
        _uninstallHook(_hook);
    }

    /**
     *  @notice A generic entrypoint to write state of any of the installed hooks.
     */
    function hookFunctionWrite(uint256 _hookFlag, bytes calldata _data) external payable returns (bytes memory) {
        if (!_canWriteToHooks(msg.sender)) {
            revert HookInstallerUnauthorizedWrite();
        }
        if (_hookFlag > 2 ** _maxHookFlag()) {
            revert HookInstallerInvalidHook();
        }

        address target = getHookImplementation(_hookFlag);
        if (target == address(0)) {
            revert HookInstallerHookNotInstalled();
        }

        (bool success, bytes memory returndata) = target.call{value: msg.value}(_data);
        if (!success) {
            _revert(returndata, HookInstallerHookCallFailed.selector);
        }

        return returndata;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view virtual returns (bool);

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view virtual returns (bool);

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure virtual returns (uint8) {
        return 0;
    }

    /// @dev Installs a hook in the contract.
    function _installHook(IHook _hook) internal {
        uint256 hooksToInstall = _hook.getHooks();

        _updateHooks(hooksToInstall, address(_hook), _addhook);
        hookImplementations_.set(uint160(address(_hook)));

        emit HooksInstalled(address(_hook), hooksToInstall);
    }

    /// @dev Uninstalls a hook in the contract.
    function _uninstallHook(IHook _hook) internal {
        if (!hookImplementations_.get(uint160(address(_hook)))) {
            revert HookInstallerHookNotInstalled();
        }

        uint256 hooksToUninstall = _hook.getHooks();

        _updateHooks(hooksToUninstall, address(0), _removehook);
        hookImplementations_.unset(uint160(address(_hook)));

        emit HooksUninstalled(address(_hook), hooksToUninstall);
    }

    /// @dev Adds a hook to the given integer represented hooks.
    function _addhook(uint256 _flag, uint256 _currenthooks) internal pure returns (uint256) {
        if (_currenthooks & _flag > 0) {
            revert HookInstallerHookAlreadyInstalled();
        }
        return _currenthooks | _flag;
    }

    /// @dev Removes a hook from the given integer represented hooks.
    function _removehook(uint256 _flag, uint256 _currenthooks) internal pure returns (uint256) {
        return _currenthooks & ~_flag;
    }

    /// @dev Updates the current active hooks of the contract.
    function _updateHooks(
        uint256 _hooksToUpdate,
        address _implementation,
        function(uint256, uint256) internal pure returns (uint256) _addOrRemovehook
    ) internal {
        uint256 currentActivehooks = installedHooks_;

        uint256 flag = 2 ** _maxHookFlag();
        while (flag > 1) {
            if (_hooksToUpdate & flag > 0) {
                currentActivehooks = _addOrRemovehook(flag, currentActivehooks);
                hookImplementationMap_[flag] = _implementation;
            }

            flag >>= 1;
        }

        installedHooks_ = currentActivehooks;
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
}
