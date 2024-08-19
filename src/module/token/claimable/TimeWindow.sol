pragma solidity ^0.8.20;

library TimeWindow {
    error OutOfTimeWindow();

    function _check(uint48 startTimestamp, uint48 endTimestamp) internal view {
        if (
            block.timestamp < startTimestamp || endTimestamp <= block.timestamp
        ) {
            revert OutOfTimeWindow();
        }
    }
}
