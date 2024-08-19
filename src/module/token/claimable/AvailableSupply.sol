pragma solidity ^0.8.20;

import {Mint} from "./Mint.sol";

library AvailableSupply {
    error OutOfSupply();

    function _check(uint256 _amount, uint256 availableSupply) internal pure {
        if (_amount > availableSupply) {
            revert OutOfSupply();
        }
    }

    function _effectsAndInteractions(
        Mint.Data storage data,
        uint256 _amount
    ) internal {
        data.availableSupply -= _amount;
    }
}
