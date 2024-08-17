pragma solidity ^0.8.20;

library Cast {

    function toAddress(uint256 _value) internal pure returns (address) {
        return address(uint160(_value));
    }

    function toUint256(address _value) internal pure returns (uint256) {
        return uint256(uint160(_value));
    }

}
