// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../Module.sol";
import {Role} from "../Role.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

library PythOracleStorage {

    /// @custom:storage-location erc7201:pyth.oracle
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

    IPyth immutable pyth;

    constructor(address _pythContract) {
        pyth = IPyth(_pythContract);
    }

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](0);
        config.fallbackFunctions = new FallbackFunction[](2);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.fetchPythPrices.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.updatePriceFeeds.selector, permissionBits: 0});

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

    function updatePriceFeeds(bytes[] calldata priceUpdate) public payable {
        uint256 fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{value: fee}(priceUpdate);
    }

    /// @notice fetchPythPrices method to update and read the latest price from a price feed.
    /// @dev Make sure to send priceUpdates for all priceFeedIds to get the latest price.
    /// @param priceFeedIds The price feed IDs to update.
    /// @param priceUpdates The price updates to submit.
    function fetchPythPrices(bytes32[] calldata priceFeedIds, bytes[] calldata priceUpdates, uint256 maxAge) public payable {
        // Submit a priceUpdate to the Pyth contract to update the on-chain price.
        // Updating the price requires paying the fee returned by getUpdateFee.
        // WARNING: These lines are required to ensure the getPriceNoOlderThan call below succeeds. If you remove them, transactions may fail with "0x19abf40e" error.
        updatePriceFeeds(priceUpdates);

        // Read the latest price from a price feed if it is less than 60 seconds old.
        // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
        for (uint32 i = 0; i < priceFeedIds.length; i++) {
            PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedIds[i], maxAge);
        }
    }
}
