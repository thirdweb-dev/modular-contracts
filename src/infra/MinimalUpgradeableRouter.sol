// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/dynamic-contracts/core/RouterPayable.sol";

contract MinimalUpgradeableRouter is RouterPayable {
    
    event ImplementationUpdate(bytes4 indexed functionSelector, address indexed implementation);

    address public immutable admin;
    address public immutable defaultImplementation;

    mapping(bytes4 => address) private _implementation;

    constructor(address _admin, address _defaultImplementation) RouterPayable() {
        admin = _admin;
        defaultImplementation = _defaultImplementation;
    }

    function setImplementationForFunction(bytes4 _functionSelector, address _implementationAddress) public {
        require(msg.sender == admin, "MinimalUpgradeableRouter: only admin can set implementation.");
        _implementation[_functionSelector] = _implementationAddress;

        emit ImplementationUpdate(_functionSelector, _implementationAddress);
    }

    function getImplementationForFunction(bytes4 _functionSelector) public view override returns (address) {
        address implementation = _implementation[_functionSelector];
        if(implementation == address(0)) {
            return defaultImplementation;
        }
        return implementation;
    }
}