// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../interface/extension/ITokenHook.sol";

abstract contract TokenHook is ITokenHook {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getBeforeMintArgSignature() external view virtual returns (string memory argSignature) {
        argSignature = "";
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address _to, uint256 _quantity, bytes memory _data) external payable virtual returns (uint256) {
        revert TokenHookNotImplemented();
    }

    function beforeTransfer(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function beforeBurn(address _from, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }

    function beforeApprove(address _from, address _to, uint256 _tokenId) external virtual {
        revert TokenHookNotImplemented();
    }
}

contract TokenHookExample is TokenHook {

    event SomeEvent();

    uint256 private _nextId;

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG | BEFORE_BURN_FLAG;
    }

    function beforeMint(address, uint256, bytes memory) external payable override returns (uint256 tokenIdToMint) {
        tokenIdToMint = _nextId++;
        emit SomeEvent();
    }

    function beforeBurn(address, uint256) external override {
        emit SomeEvent();
    }
}