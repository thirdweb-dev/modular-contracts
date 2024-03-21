// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHookInfo} from "./IHookInfo.sol";

interface IHook is IHookInfo {
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns all hooks implemented by the contract and all hook contract functions to register as
     *          callable via core contract fallback function.
     */
    function getHookInfo() external pure returns (HookInfo memory);
}
