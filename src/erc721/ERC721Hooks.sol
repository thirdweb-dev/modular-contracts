// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../lib/Address.sol";

// before/after hooks at ERC721 functions: mint, transfer, burn and approve
contract ERC721Hooks {

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    enum Hook {
        BeforeMint,
        AfterMint,
        BeforeTransfer,
        AfterTransfer,
        BeforeBurn,
        AfterBurn,
        BeforeApprove,
        AfterApprove
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event HookSet(Hook hook, address implementation);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error HookInactive(Hook hook);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(Hook => address) public hookImplementation;

    /*//////////////////////////////////////////////////////////////
                            HOOKS MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier burnHooks(address _from, uint256 _tokenId, bytes memory _data) {
        _beforeBurn(_from, _tokenId, _data);
        _;
        _afterBurn(_from, _tokenId, _data);
    }

    modifier mintHooks(address _to, uint256 _tokenId, bytes memory _data) {
        _beforeMint(_to, _tokenId, _data);
        _;
        _afterMint(_to, _tokenId, _data);
    }

    modifier transferHooks(address _from, address _to, uint256 _tokenId, bytes memory _data) {
        _beforeTransfer(_from, _to, _tokenId, _data);
        _;
        _afterTransfer(_from, _to, _tokenId, _data);
    }

    modifier approveHooks(address _from, address _to, uint256 _tokenId, bytes memory _data) {
        _beforeApprove(_from, _to, _tokenId, _data);
        _;
        _afterApprove(_from, _to, _tokenId, _data);
    }
    
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _diableHook(Hook hook) internal {
        delete hookImplementation[hook];
        emit HookSet(hook, address(0));
    }

    function _setHookImplementation(address _implementation, Hook hook) internal {
        hookImplementation[hook] = _implementation;
        emit HookSet(hook, _implementation);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOKS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _beforeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.BeforeMint];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeMint(to, tokenId, data);
        }
    }

    function _afterMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.AfterMint];

        if(hook != address(0)) {
            IHooksERC721(hook).afterMint(to, tokenId, data);
        }
    }

    function _beforeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.BeforeTransfer];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeTransfer(from, to, tokenId, data);
        }
    }

    function _afterTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.AfterTransfer];

        if(hook != address(0)) {
            IHooksERC721(hook).afterTransfer(from, to, tokenId, data);
        }
    }

    function _beforeBurn(address from, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.BeforeBurn];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeBurn(from, tokenId, data);
        }
    }

    function _afterBurn(address from, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.AfterBurn];

        if(hook != address(0)) {
            IHooksERC721(hook).afterBurn(from, tokenId, data);
        }
    }

    function _beforeApprove(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.BeforeApprove];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeApprove(from, to, tokenId, data);
        }
    }

    function _afterApprove(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        address hook = hookImplementation[Hook.AfterApprove];

        if(hook != address(0)) {
            IHooksERC721(hook).afterApprove(from, to, tokenId, data);
        }
    }
}

interface IHooksERC721 {
    function beforeMint(address to, uint256 tokenId, bytes memory data) external;

    function afterMint(address to, uint256 tokenId, bytes memory data) external;

    function beforeTransfer(address from, address to, uint256 tokenId, bytes memory data) external;

    function afterTransfer(address from, address to, uint256 tokenId, bytes memory data) external;

    function beforeBurn(address from, uint256 tokenId, bytes memory data) external;

    function afterBurn(address from, uint256 tokenId, bytes memory data) external;

    function beforeApprove(address from, address to, uint256 tokenId, bytes memory data) external;

    function afterApprove(address from, address to, uint256 tokenId, bytes memory data) external;
}

