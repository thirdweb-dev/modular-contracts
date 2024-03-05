// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {BenchmarkERC721ThirdwebLegacy} from "./BenchmarkERC721ThirdwebLegacy.sol";
import {BenchmarkERC721Manifold} from "./BenchmarkERC721Manifold.sol";

contract BenchmarkERC721 is Script {
    function deployThirdwebLegacy() public {
        BenchmarkERC721ThirdwebLegacy benchmark = new BenchmarkERC721ThirdwebLegacy();
        benchmark.run(msg.sender);
    }

    function deployThirdweb() public {}

    function deployManifold() public {
        BenchmarkERC721Manifold benchmark = new BenchmarkERC721Manifold();
        benchmark.run(msg.sender);
    }

    function deployZora() public {
        // premint
        // https://sepolia.explorer.zora.energy/tx/0x1daffd513abf5a8ab1b73bbc9c9dbb1fb576c64069a9a5b6afd2f34ccda5caf6
    }

    function run() external {
        vm.startBroadcast();
        deployThirdwebLegacy();
        deployManifold();
    }
}
