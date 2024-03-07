// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    /// @dev Returns the name of the token.
    function name() public view override returns (string memory) {
        return "MockERC20";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return "MERC";
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }
}
