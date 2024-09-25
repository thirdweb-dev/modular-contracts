// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Core} from "../Core.sol";
import {IERC20} from "../interface/IERC20.sol";

contract SplitWalletCore is Core {

    address public immutable splitFees;

    constructor(address _owner, address[] memory _modules, bytes[] memory _moduleInstallData) {
        splitFees = msg.sender;
        _initializeOwner(_owner);

        // Install and initialize modules
        require(_modules.length == _moduleInstallData.length);
        for (uint256 i = 0; i < _modules.length; i++) {
            _installModule(_modules[i], _moduleInstallData[i]);
        }
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}
