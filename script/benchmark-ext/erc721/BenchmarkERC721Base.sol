// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

interface IERC721 {

    function transferFrom(address from, address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool _approved) external;

}

abstract contract BenchmarkERC721Base {

    // Step 1: Deploy a contract through factory or create
    // Step 2: Setup the collection with token URI
    // Step 3: Mint an NFT
    // Step 4: Mint 100 NFTs
    // Step 5: Transfer 1 Token
    function deployContract(
        address deployerAddress,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) external virtual returns (address contractAddress);

    function setupToken(address contractAddress) external virtual;

    function mintToken(address contractAddress) external virtual;

    function mintBatchTokens(address contractAddress) external virtual;

    function transferTokenFrom(address contractAddress) external virtual;

}
