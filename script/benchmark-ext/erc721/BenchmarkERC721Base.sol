// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract BenchmarkERC721Base {
    // Step 1: Deploy a contract through factory or create
    // Step 2: Setup the collection with token URI
    // Step 3: Mint an NFT
    // Step 4: Mint 100 NFTs
    // Step 5: Transfer 1 Token
    function _deployContract(
        address deployerAddress,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) internal virtual returns (address contractAddress);

    function _setupToken() internal virtual;

    function _mintToken() internal virtual;

    function _mintBatchHundredTokens() internal virtual;

    function _transferToken() internal virtual;

    function run(address deployerAddress) external {
        _deployContract(
            deployerAddress,
            "BenchmarkERC721",
            "B721",
            "ipfs://QmSkieqXz9voc614Q5LAhQY13LjX6bUzqp2dpDdJhARL7X/0"
        );
    }
}
