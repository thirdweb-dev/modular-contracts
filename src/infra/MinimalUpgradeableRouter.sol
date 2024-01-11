// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/dynamic-contracts/core/RouterPayable.sol";

/// NOTE: This contract is not meant for production use. It is only meant to be used for testing purposes.

contract MinimalUpgradeableRouter is RouterPayable {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ImplementationUpdate(bytes4 indexed functionSelector, address indexed implementation);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable admin;
    address public immutable defaultImplementation;
    mapping(bytes4 => address) private _implementation;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, address _defaultImplementation) RouterPayable() {
        admin = _admin;
        defaultImplementation = _defaultImplementation;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getImplementationForFunction(bytes4 _functionSelector) public view override returns (address) {
        address implementation = _implementation[_functionSelector];
        if (implementation == address(0)) {
            return defaultImplementation;
        }
        return implementation;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setImplementationForFunction(bytes4 _functionSelector, address _implementationAddress) public {
        require(msg.sender == admin, "MinimalUpgradeableRouter: only admin can set implementation.");
        _implementation[_functionSelector] = _implementationAddress;

        emit ImplementationUpdate(_functionSelector, _implementationAddress);
    }
}
