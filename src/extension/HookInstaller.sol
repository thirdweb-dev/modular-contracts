// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "../lib/LibBitmap.sol";
import {IHook} from "../interface/extension/IHook.sol";
import {IHookInstaller} from "../interface/extension/IHookInstaller.sol";

abstract contract HookInstaller is IHookInstaller {
    using LibBitmap for LibBitmap.Bitmap;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Should return the max flag that represents a hook.
    uint256 public constant MAX_HOOK_FLAG = 0;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing all hooks installed.
    uint256 private _installedHooks;

    /// @notice Whether a given hook is installed in the contract.
    LibBitmap.Bitmap private _hookImplementations;

    /// @notice Mapping from hook bits representation => implementation of the hook.
    mapping(uint256 => address) private _hookImplementationMap;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Retusn the implementation of a given hook, if any.
     *  @param _flag The bits representing the hook.
     *  @return impl The implementation of the hook.
     */
    function getHookImplementation(uint256 _flag) public view returns (address) {
        return _hookImplementationMap[_flag];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Installs a hook in the contract.
     *  @dev Maps all hook functions implemented by the hook to the hook's address.
     *  @param _hook The hook to install.
     */
    function installHook(IHook _hook) external {
        if (!_canUpdateHooks(msg.sender)) {
            revert HookNotAuthorized();
        }

        uint256 hooksToInstall = _hook.getHooksImplemented();

        _updateHooks(hooksToInstall, address(_hook), _addHook);
        _hookImplementations.set(uint160(address(_hook)));

        emit HooksInstalled(address(_hook), hooksToInstall);
    }

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param _hook The hook to uninstall.
     */
    function uninstallHook(IHook _hook) external {
        if (!_canUpdateHooks(msg.sender)) {
            revert HookNotAuthorized();
        }
        if (!_hookImplementations.get(uint160(address(_hook)))) {
            revert HookIsNotInstalled();
        }

        uint256 hooksToUninstall = _hook.getHooksImplemented();

        _updateHooks(hooksToUninstall, address(0), _removeHook);
        _hookImplementations.unset(uint160(address(_hook)));

        emit HooksUninstalled(address(_hook), hooksToUninstall);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view virtual returns (bool);

    function _addHook(uint256 _flag, uint256 _currentHooks) internal pure returns (uint256) {
        if (_currentHooks & _flag > 0) {
            revert HookAlreadyInstalled();
        }
        return _currentHooks | _flag;
    }

    function _removeHook(uint256 _flag, uint256 _currentHooks) internal pure returns (uint256) {
        return _currentHooks & ~_flag;
    }

    function _updateHooks(
        uint256 _hooksToUpdate,
        address _implementation,
        function (uint256, uint256) internal pure returns (uint256) _addOrRemoveHook
    ) internal {
        uint256 currentActiveHooks = _installedHooks;

        uint256 flag = 2 ** MAX_HOOK_FLAG;
        while (flag > 1) {
            if (_hooksToUpdate & flag > 0) {
                currentActiveHooks = _addOrRemoveHook(flag, currentActiveHooks);
                _hookImplementationMap[flag] = _implementation;
            }

            flag >>= 1;
        }

        _installedHooks = currentActiveHooks;
    }
}
