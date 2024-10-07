// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../Module.sol";
import {Role} from "../Role.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

library PythOracleStorage {

    /// @custom:storage-location erc7201:token.minting.mintable
    bytes32 public constant PYTH_ORACLE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("pyth.oracle")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address pythContract;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = PYTH_ORACLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract PythOracle is Module {

    address immutable pythContract;

    constructor(address _pythContract) {
        pythContract = _pythContract;
    }

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](0);
        config.fallbackFunctions = new FallbackFunction[](1);

        fallbackFunctions[0] = FallbackFunction({selector: this.exampleMethod.selector, permissionBits: 0});

        config.registerInstallationCallback = true;
    }

    function onInstall(bytes calldata data) external {
        address pythContract = abi.decode(data, (address));
        PythOracleStorage.data().pythContract = pythContract;
    }

    function onUninstall(bytes calldata data) external {}

    function encodeBytesOnInstall(address pythContract) external pure returns (bytes memory) {
        return abi.encode(pythContract);
    }

    function encodeBytesOnUninstall() external pure returns (bytes memory) {}

    function exampleMethod(bytes[] calldata priceUpdate) public payable {
        // Submit a priceUpdate to the Pyth contract to update the on-chain price.
        // Updating the price requires paying the fee returned by getUpdateFee.
        // WARNING: These lines are required to ensure the getPriceNoOlderThan call below succeeds. If you remove them, transactions may fail with "0x19abf40e" error.
        uint256 fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{value: fee}(priceUpdate);

        // Read the current price from a price feed if it is less than 60 seconds old.
        // Each price feed (e.g., ETH/USD) is identified by a price feed ID.
        // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
        bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // ETH/USD
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedId, 60);
    }

}
