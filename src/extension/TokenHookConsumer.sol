// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {LibBitmap} from "../lib/LibBitmap.sol";
import {ITokenHook, ITokenHookConsumer} from "../interface/extension/ITokenHookConsumer.sol";

abstract contract TokenHookConsumer is ITokenHookConsumer {
    using LibBitmap for LibBitmap.Bitmap;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_FLAG = 2 ** 6;

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

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (HookImplementation memory hooks) {
        hooks = HookImplementation({
            beforeMint: _hookImplementationMap[BEFORE_MINT_FLAG],
            beforeTransfer: _hookImplementationMap[BEFORE_TRANSFER_FLAG],
            beforeBurn: _hookImplementationMap[BEFORE_BURN_FLAG],
            beforeApprove: _hookImplementationMap[BEFORE_APPROVE_FLAG],
            tokenUri: _hookImplementationMap[TOKEN_URI_FLAG],
            royalty: _hookImplementationMap[ROYALTY_FLAG]
        });
    }

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
    function installHook(ITokenHook _hook) external {
        if (!_canUpdateHooks(msg.sender)) {
            revert TokenHookConsumerNotAuthorized();
        }

        uint256 hooksToInstall = _hook.getHooksImplemented();

        _updateHooks(hooksToInstall, address(_hook), _addHook);
        _hookImplementations.set(uint160(address(_hook)));

        emit TokenHookInstalled(address(_hook), hooksToInstall);
    }

    /**
     *  @notice Uninstalls a hook in the contract.
     *  @dev Reverts if the hook is not installed already.
     *  @param _hook The hook to uninstall.
     */
    function uninstallHook(ITokenHook _hook) external {
        if (!_canUpdateHooks(msg.sender)) {
            revert TokenHookConsumerNotAuthorized();
        }
        if (!_hookImplementations.get(uint160(address(_hook)))) {
            revert TokenHookConsumerHookDoesNotExist();
        }

        uint256 hooksToUninstall = _hook.getHooksImplemented();

        _updateHooks(hooksToUninstall, address(0), _removeHook);
        _hookImplementations.unset(uint160(address(_hook)));

        emit TokenHookUninstalled(address(_hook), hooksToUninstall);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view virtual returns (bool);

    /// @dev Returns the largest power of 2 that represents a hook.
    function _maxFlagIndex() internal pure virtual returns (uint8) {
        return 6;
    }

    function _addHook(uint256 _flag, uint256 _currentHooks) internal pure returns (uint256) {
        if (_currentHooks & _flag > 0) {
            revert TokenHookConsumerHookAlreadyExists();
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

        uint256 flag = 2 ** _maxFlagIndex();
        while (flag > 1) {
            if (_hooksToUpdate & flag > 0) {
                currentActiveHooks = _addOrRemoveHook(flag, currentActiveHooks);
                _hookImplementationMap[flag] = _implementation;
            }

            flag >>= 1;
        }

        _installedHooks = currentActiveHooks;
    }

    /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address _to, uint256 _quantity, bytes memory _data)
        internal
        virtual
        returns (bool success, uint256 tokenIdToMint, uint256 _quantityToMint)
    {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (tokenIdToMint, _quantityToMint) = ITokenHook(hook).beforeMint{value: msg.value}(_to, _quantity, _data);
            success = true;
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _tokenId) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            ITokenHook(hook).beforeTransfer(_from, _to, _tokenId);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _tokenId) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            ITokenHook(hook).beforeBurn(_from, _tokenId);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _tokenId) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            ITokenHook(hook).beforeApprove(_from, _to, _tokenId);
        }
    }
}
