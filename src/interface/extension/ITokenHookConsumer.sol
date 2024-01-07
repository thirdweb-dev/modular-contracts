// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { ITokenHook } from "./ITokenHook.sol";

interface ITokenHookConsumer {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct HookImplementation {
        address beforeMint;
        address afterMint;
        address beforeTransfer;
        address afterTransfer;
        address beforeBurn;
        address afterBurn;
        address beforeApprove;
        address afterApprove;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenHookConsumerNotAuthorized();
    error TokenHookConsumerHookAlreadyExists();
    error TokenHookConsumerHookDoesNotExist();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenHookInstalled(address indexed implementation, uint256 hooks);
    event TokenHookUninstalled(address indexed implementation, uint256 hooks);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAllHooks() external view returns (HookImplementation memory hooks);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function installHook(ITokenHook _hook) external;

    function uninstallHook(ITokenHook _hook) external;
}