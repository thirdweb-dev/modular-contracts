// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

library Historical {
    struct Timeline {
        Checkpoint[] checkpoints;
    }

    struct Checkpoint {
        uint48 key;
        uint208 value;
    }

    error InvalidCheckpoint(uint48 key);

    function lookup(Timeline storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self.checkpoints.length;
        uint256 pos = _binaryLookup(self.checkpoints, key, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self.checkpoints, pos - 1).value;
    }

    function latest(Timeline storage self) internal view returns (uint208) {
        uint256 pos = self.checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self.checkpoints, pos - 1).value;
    }

    function push(Timeline storage self, uint48 key, uint208 value) internal returns (uint208, uint208) {
        return _insert(self.checkpoints, key, value);
    }

    function _insert(Checkpoint[] storage self, uint48 key, uint208 value) private returns (uint208, uint208) {
        uint256 pos = self.length;
        if (pos > 0) {
            Checkpoint memory last = _unsafeAccess(self, pos - 1);
            if (last.key > key) revert InvalidCheckpoint(key); 

            self.push(Checkpoint({key: key, value: value}));
            return (last.value, value);
        } else {
            self.push(Checkpoint({key: key, value: value}));
            return (0, value);
        }
   }

    function _binaryLookup(
        Checkpoint[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2; // calculate average
            if (_unsafeAccess(self, mid).key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    function _unsafeAccess(
        Checkpoint[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }
}