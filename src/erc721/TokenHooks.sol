// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../lib/Address.sol";

interface ITokenHook {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Hooks {
        bool beforeMint;
        bool afterMint;
        bool beforeTransfer;
        bool afterTransfer;
        bool beforeBurn;
        bool afterBurn;
        bool beforeApprove;
        bool afterApprove;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAllHooks() external view returns (Hooks memory hooks);
}

interface ITokenHookImplementation is ITokenHook {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error HookNotImplemented();

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address to, uint256 tokenId, bytes memory data) external payable;

    function afterMint(address to, uint256 tokenId) external;

    function beforeTransfer(address from, address to, uint256 tokenId) external;

    function afterTransfer(address from, address to, uint256 tokenId) external;

    function beforeBurn(address from, uint256 tokenId) external;

    function afterBurn(address from, uint256 tokenId) external;

    function beforeApprove(address from, address to, uint256 tokenId) external;

    function afterApprove(address from, address to, uint256 tokenId) external;
}

interface ITokenHookRegister is ITokenHook {

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHookImplementation(uint256 hookFlag) external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function activateHooks(uint256 hookBits, address implementation) external;

    function deactivateHooks(uint256 hookBits) external;
}

abstract contract TokenHookRegister is ITokenHookRegister {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;
    uint256 public constant AFTER_MINT_FLAG = 2 ** 2;
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 3;
    uint256 public constant AFTER_TRANSFER_FLAG = 2 ** 4;
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 5;
    uint256 public constant AFTER_BURN_FLAG = 2 ** 6;
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 7;
    uint256 public constant AFTER_APPROVE_FLAG = 2 ** 8;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event HooksUpdated(uint256 allActiveHooks, uint256 hooksUpdated, address indexed implementation);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenHooksNotAuthorized();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private activeHooks;

    mapping(uint256 => address) private hookImplementation;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAllHooks() external view returns (Hooks memory) {
        return Hooks({
            beforeMint: _isHookActive(BEFORE_MINT_FLAG),
            afterMint: _isHookActive(AFTER_MINT_FLAG),
            beforeTransfer: _isHookActive(BEFORE_TRANSFER_FLAG),
            afterTransfer: _isHookActive(AFTER_TRANSFER_FLAG),
            beforeBurn: _isHookActive(BEFORE_BURN_FLAG),
            afterBurn: _isHookActive(AFTER_BURN_FLAG),
            beforeApprove: _isHookActive(BEFORE_APPROVE_FLAG),
            afterApprove: _isHookActive(AFTER_APPROVE_FLAG)
        });
    }

    function getHookImplementation(uint256 _hookFlag) public view returns (address) {
        return hookImplementation[_hookFlag];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function activateHooks(uint256 _hookBits, address _implementation) external {
        if(!_canSetHooks()) {
            revert TokenHooksNotAuthorized();
        }
        _updateHooks(_hookBits, _implementation, _activate);
    }

    function deactivateHooks(uint256 _hookBits) external {
        if(!_canSetHooks()) {
            revert TokenHooksNotAuthorized();
        }
        _updateHooks(_hookBits, address(0), _deactivate);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _canSetHooks() internal view virtual returns (bool);

    function _isHookActive(uint256 _hookBits) internal view returns (bool) {
        return activeHooks & _hookBits > 0;
    }

    function _activate(uint256 _hook, uint256 _hookBits) internal pure returns (uint256 _updatedHooks) {
        _updatedHooks = _hookBits | _hook;
    }

    function _deactivate(uint256 _hook, uint256 _hookBits) internal pure returns (uint256 _updatedHooks) {
        _updatedHooks = _hookBits & ~_hook;
    }

    function _updateHooks(uint256 _hookBits, address _implementation, function (uint256, uint256) internal pure returns (uint256) _update) internal {
        uint256 hook = 2 ** 8;
        uint256 active = activeHooks;
        
        while (hook > 0) {
            if (_hookBits & hook > 0) {
                active = _update(hook, _hookBits);
                hookImplementation[hook] = _implementation;
            }
            hook = hook >> 1;
        }
        activeHooks = active;

        emit HooksUpdated(active, _hookBits, address(0));
    }
}