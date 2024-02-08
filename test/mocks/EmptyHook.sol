// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/hook/ERC20Hook.sol";

contract EmptyHookERC20 is ERC20Hook {
    function initialize() public initializer {}

    function getHooks() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG();
    }

    function beforeMint(
        address _claimer,
        uint256 _quantity,
        bytes memory _encodedArgs
    ) external payable virtual override returns (uint256 quantityToMint) {
        return _quantity;
    }
}
