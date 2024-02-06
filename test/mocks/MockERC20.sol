// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/core/token/ERC20Initializable.sol";

contract MockERC20 is ERC20Initializable {

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }
}