// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../interface/extension/ITokenHook.sol";

abstract contract TokenHook is ITokenHook {

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
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address _to, bytes memory _data) external payable virtual returns (uint256) {
        revert TokenHookNotImplemented();
    }

    function afterMint(address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function beforeTransfer(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function afterTransfer(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function beforeBurn(address _from, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function afterBurn(address _from, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function beforeApprove(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function afterApprove(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }
}

contract TokenHookExample is TokenHook {

    event TokenMinted(uint256);

    uint256 private _nextId;

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | AFTER_MINT_FLAG;
    }

    function beforeMint(address, bytes memory) external payable override returns (uint256 tokenIdToMint) {
        tokenIdToMint = _nextId++;
        emit TokenMinted(tokenIdToMint);
    }

    function afterMint(address, uint256 _tokenId) external override {
        emit TokenMinted(_tokenId);
    }
}