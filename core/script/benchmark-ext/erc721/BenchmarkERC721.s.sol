// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IERC721} from "./BenchmarkERC721Base.sol";
import {BenchmarkERC721ThirdwebLegacy} from "./BenchmarkERC721ThirdwebLegacy.sol";
import {BenchmarkERC721Manifold} from "./BenchmarkERC721Manifold.sol";

contract BenchmarkERC721 is Script {
    function benchmarkThirdwebLegacy() public {
        BenchmarkERC721ThirdwebLegacy benchmark = new BenchmarkERC721ThirdwebLegacy();

        address contractAddress = benchmark.deployContract(
            address(benchmark), "BenchmarkERC721", "B721", "ipfs://QmSkieqXz9voc614Q5LAhQY13LjX6bUzqp2dpDdJhARL7X/0"
        );
        benchmark.mintToken(contractAddress);
        IERC721(contractAddress).setApprovalForAll(address(benchmark), true);
        benchmark.transferTokenFrom(contractAddress);
    }

    function benchmarkManifold() public {
        BenchmarkERC721Manifold benchmark = new BenchmarkERC721Manifold();
        address contractAddress = benchmark.deployContract(address(0), "BenchmarkERC721", "B721", "");
        benchmark.mintToken(contractAddress);
        IERC721(contractAddress).setApprovalForAll(address(benchmark), true);
        benchmark.transferTokenFrom(contractAddress);
    }

    function benchmarkThirdwebNext() public {}

    function benchmarkZora() public {
        // premint
        // https://sepolia.explorer.zora.energy/tx/0x1daffd513abf5a8ab1b73bbc9c9dbb1fb576c64069a9a5b6afd2f34ccda5caf6
    }

    function run() external {
        vm.startBroadcast();
        benchmarkThirdwebLegacy();
        benchmarkManifold();
    }
}
