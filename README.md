<p align="center">
<br />
<a href="https://thirdweb.com"><img src="https://github.com/thirdweb-dev/typescript-sdk/blob/main/logo.svg?raw=true" width="200" alt=""/></a>
<br />
</p>
<h1 align="center">thirdweb Contracts-Next</h1>
<p align="center"><strong>Next iteration of thirdweb smart contracts. Install extensions in core contracts.</strong></p>
<br />

> :mega: **Call for feedback**: These contracts are NOT AUDITED. This design update is WIP and we encourage opening an issue with feedback.

# Run this repo

Clone the repo:

```bash
git clone https://github.com/thirdweb-dev/contracts-next.git
```

Install dependencies:

```bash
forge install && yarn
```

Run benchmark comparison tests:

```bash
forge test --mc Thirdweb # or Manifold / Zora
```

## Usage

You can find testnet deployments of this extensions design setup, and JS scripts to interact with an ERC-721 core contract and its extensions here: https://github.com/thirdweb-dev/contracts-next-scripts

# Benchmarks

### ERC-721 Core Benchmarks via transactions on Goerli

| Action                                      | Gas consumption | Transaction                                                                                              |
| ------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------- |
| Mint 1 token (token ID `0`)                 | 145_373         | [ref](https://goerli.etherscan.io/tx/0x1de1431200f6d39e9f4ddba3386e413078308a6eae1ebcc722884443b643d7d0) |
| Mint 1 token (token ID `>0`)                | 116_173         | [ref](https://goerli.etherscan.io/tx/0xc38e82228a1f8cf877abfeeb28e3f294bb38b90f51cbb2df1c899f03fad4e355) |
| Mint 10 tokens (including token ID `0`)     | 365_414         | [ref](https://goerli.etherscan.io/tx/0x1e8a79bd1806a3410a46f8d0ec0fcff099e3aeff6d4e64815c1f400ab092c77e) |
| Mint 10 tokens (not including token ID `0`) | 331_214         | [ref](https://goerli.etherscan.io/tx/0xe4ab2650f8827d52d2ec15956da910915b2b08f67d3f59ac8091da2fbd0369a0) |
| Transfer token                              | 64_389          | [ref](https://goerli.etherscan.io/tx/0x3ca2c4c74d6c8a4859fd78af5091c4dc4dc0fc0452202b18b611e4f0308c3673) |
| Install 1 extension                              | 105_455         | [ref](https://goerli.etherscan.io/tx/0x8df68fefe6f0318220795f4c56aec81fdafea2a3d17da2d45a0a762aac6cf6d0) |
| Install 5 extensions                             | 191_918         | [ref](https://goerli.etherscan.io/tx/0x184f59ce6f83a6927e2269879bdec9ccd29f8ed3fd98be9d4d359e34cfde4ce5) |
| Uninstall 1 extension                            | 43_468          | [ref](https://goerli.etherscan.io/tx/0x30c678277603c80b1f412049b13ba6742712c64ef9973b00d8866169589ad40f) |
| Uninstall 5 extensions                           | 57_839          | [ref](https://goerli.etherscan.io/tx/0xf1869d1b6fdc0f7e340cd30df2f0b57408cf0d752e4898ef14836a7672877050) |

**Note:**

- 'Minting tokens' benchmarks use the `AllowlistMintExtension` contract as the `beforeMint` extension. All token minting benchmarks include distributing non-zero primary sale value and platform fee.
- All extensions used in these benchmarks are minimal clone proxy contracts pointing to extension contract implementations.

### ERC-721 Contracts Benchmarks Comparison via transactions on Sepolia

| Action                    | Thirdweb (Extensions) | Thirdweb Drop | Zora    | Manifold |
| ------------------------- | ------------ | ------------- | ------- | -------- |
| Deploy (developer-facing) | 213_434 [tx](https://sepolia.etherscan.io/tx/0x4899fd74e09b4994162f0ce4ea8783a93712825cb20373612263cbfcf83137dc)      | 719_842 [tx](https://sepolia.etherscan.io/tx/0x69bf0d597b4db864d50b1c592451156e23a0eca598fd337f0888f3f0d45eda85)      | 499_968 [tx](https://sepolia.etherscan.io/tx/0x1d3e653ab587f3203abdcb233ca3502f5a99b2ba38c62b9097b4d9cecac39016) | 232_917 [tx](https://sepolia.etherscan.io/tx/0x80fcff853e07bb99475e0258c315eaf4f91f6e954f9edc170e05a833568401d3)  |
| Claim 1 token             | 149_142 [tx](https://sepolia.etherscan.io/tx/0xce9155496a5e1705fd91e25fa5c4b6a2664ee8951010e0d236b8f1bc1bebb2a9)      | 196_540 [tx](https://sepolia.etherscan.io/tx/0xd2d5eaa191ebe342f34a2647a253782795d93cecc90ae0e3de4bb6a6afe29d0a)      | 160_447 [tx](https://sepolia.etherscan.io/tx/0xe1b431c28f0cc8d03489ea1a54fb6b70eea4dc0210cbf24f9cf6b22c3a68f99d) | 184_006 [tx](https://sepolia.etherscan.io/tx/0x149ac1f2aec78753f73a7b16bdea9dd81dc5823893a128422499ba49af3b07f4)  |
| Transfer token            | 59_587 [tx](https://sepolia.etherscan.io/tx/0x252311fc0ada4873d8fcc036ec7145b1dfb76bef7d974aae15111623cf4e889b)      | 76_102 [tx](https://sepolia.etherscan.io/tx/0xd5dd3f3f33e6755fd07617795a382e7e34005771a6374dacbfb686c6b4d981cc)       | 71_362 [tx](https://sepolia.etherscan.io/tx/0x4f3d79e1b5582ebab5ff6e1f343d640b2e47ded458223de4e1cf248f1c72776d) | 69_042 [tx](https://sepolia.etherscan.io/tx/0xb3eb80ea9cf88d3a731490f6c9fd8c3f9d8b8283e5b376e4aaf001fb46e84ae2)  |
| Setup token metadata      | 60_217 [tx](https://sepolia.etherscan.io/tx/0xfe99caf84e543f1b73055da7ef23f8071d3b8d893c838c12b9b3567f0a4cdcb8)      | 47_528 [tx](https://sepolia.etherscan.io/tx/0x6526f514b47d60785eb3951046dc1e30b175d2aa74aa2693932ea68ed2054d4d)       | 54_612 [tx](https://sepolia.etherscan.io/tx/0xd959c6dfc531994bca58df41c30952a04a6f1ab7e86b3ab3457ed4f4d5bd1846)  | 29_789 [tx](https://sepolia.etherscan.io/tx/0x1d3e653ab587f3203abdcb233ca3502f5a99b2ba38c62b9097b4d9cecac39016)  |

# Design Overview

Developers deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-721 Core contract.

- This contract is initializable, and meant to be used with proxy contracts.
- Implements the token standard (and the respective token metadata standard).
- Uses the role based permission model of the [`Permission`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/common/Permission.sol) contract.
- Implements the [`ExtensionInstaller`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/extension/ExtensionInstaller.sol) interface.

Core contracts are deliberately written as non-upgradeable foundations that contain minimal code with fixed behaviour. These contracts are meant to be extended by developers using extensions.

## Extensions and Modularity

![mint tokens via extensions](https://ipfs.io/ipfs/QmXfN8GFsJNEgkwa9F44kRWFFnahPbyPb8yV2L9LmFomnj/contracts-next-mint-tokens.png)

Extensions are an external call made to a contract that implements the [`IExtension`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/interface/extension/IExtension.sol) interface.

The purpose of extensions is to allow developers to extend their contract's functionality by running custom logic right before a token is minted, transferred, burned, or approved, or for returning a token's metadata or royalty info.

For example, there is a fixed, defined set of 6 ERC-721 extensions:

- **BeforeMint**: called before a token is minted in the ERC721Core.mint call.
- **BeforeTransfer**: called before a token is transferred in the ERC721.transferFrom call.
- **BeforeBurn**: called before a token is burned in the ERC721.burn call.
- **BeforeApprove**: called before the ERC721.approve and ERC721.setApprovalForAll call.
- **Token URI**: called when the ERC721Metadata.tokenURI function is called.
- **Royalty**: called when the ERC2981.royaltyInfo function is called.

Developers can install extensions into their core contracts, and uninstall extensions at any time. On installation, a extension contract tells the extension consumer which extension functions it implements -- the extension consumer maps all these extension functions to the mentioned extension contract as their implemention.

## Upgradeability

![beacon upgrade](https://ipfs.io/ipfs/QmS1zU629FoDZM1X3oRmMZyxi7ThW2UiFybK7mkpZ2DzBS/contracts-next-beacon-upgrade.png)

thirdweb will publish upgradeable, 'shared state' extensions for developers (see [src/extensions](https://github.com/thirdweb-dev/contracts-next/tree/main/src/extension)).

These extension contracts are designed to be used by developers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make beacon upgrades to developer contracts using these extensions.

At any point, developers can opt to use any custom, non-thirdweb extensions along with their core contract. Without the involvement on delegateCall based upgradeability, writing extensions should be accessible for more developers, and we expect to form a vibrant extensions ecosystem.

That said, opting out of using extensions where thirdweb has upgrade authority also means that thirdweb will not be able to perform beacon upgrades to those extensions in the event of a security incident.

## Feedback

If you have any feedback, please create an issue or reach out to us at support@thirdweb.com.

## Authors

- [thirdweb](https://thirdweb.com)

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt)
