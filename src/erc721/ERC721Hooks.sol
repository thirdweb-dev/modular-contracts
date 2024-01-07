// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../lib/Address.sol";
import { TokenHookRegister } from "./TokenHooks.sol";

// before/after hooks at ERC721 functions: mint, transfer, burn and approve
contract ERC721Hooks is TokenHookRegister {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoBeforeMintHook();

    /*//////////////////////////////////////////////////////////////
                            HOOKS MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier burnHooks(address _from, uint256 _tokenId) {
        _beforeBurn(_from, _tokenId);
        _;
        _afterBurn(_from, _tokenId);
    }

    modifier mintHooks(address _to, uint256 _tokenId, bytes memory _data) {
        _beforeMint(_to, _tokenId, _data);
        _;
        _afterMint(_to, _tokenId);
    }

    modifier transferHooks(address _from, address _to, uint256 _tokenId) {
        _beforeTransfer(_from, _to, _tokenId);
        _;
        _afterTransfer(_from, _to, _tokenId);
    }

    modifier approveHooks(address _from, address _to, uint256 _tokenId) {
        _beforeApprove(_from, _to, _tokenId);
        _;
        _afterApprove(_from, _to, _tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOKS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _beforeMint(address to, uint256 tokenId, bytes memory data) internal virtual {

        if(!_isHookActive(BEFORE_MINT_FLAG)) {
            revert NoBeforeMintHook();
        }
        IHooksERC721(getHookImplementation(BEFORE_MINT_FLAG)).beforeMint{value: msg.value}(to, tokenId, data);
    }

    function _afterMint(address to, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.AfterMint];

        if(hook != address(0)) {
            IHooksERC721(hook).afterMint(to, tokenId);
        }
    }

    function _beforeTransfer(address from, address to, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.BeforeTransfer];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeTransfer(from, to, tokenId);
        }
    }

    function _afterTransfer(address from, address to, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.AfterTransfer];

        if(hook != address(0)) {
            IHooksERC721(hook).afterTransfer(from, to, tokenId);
        }
    }

    function _beforeBurn(address from, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.BeforeBurn];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeBurn(from, tokenId);
        }
    }

    function _afterBurn(address from, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.AfterBurn];

        if(hook != address(0)) {
            IHooksERC721(hook).afterBurn(from, tokenId);
        }
    }

    function _beforeApprove(address from, address to, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.BeforeApprove];

        if(hook != address(0)) {
            IHooksERC721(hook).beforeApprove(from, to, tokenId);
        }
    }

    function _afterApprove(address from, address to, uint256 tokenId) internal virtual {
        address hook = hookImplementation[Hook.AfterApprove];

        if(hook != address(0)) {
            IHooksERC721(hook).afterApprove(from, to, tokenId);
        }
    }
}

interface IHooksERC721 {
    function beforeMint(address to, uint256 tokenId, bytes memory data) external payable;

    function afterMint(address to, uint256 tokenId) external;

    function beforeTransfer(address from, address to, uint256 tokenId) external;

    function afterTransfer(address from, address to, uint256 tokenId) external;

    function beforeBurn(address from, uint256 tokenId) external;

    function afterBurn(address from, uint256 tokenId) external;

    function beforeApprove(address from, address to, uint256 tokenId) external;

    function afterApprove(address from, address to, uint256 tokenId) external;
}

