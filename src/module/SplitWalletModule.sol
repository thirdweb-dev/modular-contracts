pragma solidity ^0.8.20;

import {IERC20} from "./interface/IERC20.sol";
import {Cast} from "./libraries/Cast.sol";
import {ShortString, ShortStrings} from "./libraries/ShortString.sol";

import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC6909} from "@solady/tokens/ERC6909.sol";
import {LibClone} from "@solady/utils/LibClone.sol";

import {Module} from "../Module.sol";

library SplitFeesStorage {

    /// @custom:storage-location erc7201:split.wallet
    bytes32 public constant SPLIT_WALLET_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("split.main")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address splitMain;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SPLIT_WALLET_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract SplitWalletModule is {
}


