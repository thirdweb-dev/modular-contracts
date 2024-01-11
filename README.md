<p align="center">
<br />
<a href="https://thirdweb.com"><img src="https://github.com/thirdweb-dev/typescript-sdk/blob/main/logo.svg?raw=true" width="200" alt=""/></a>
<br />
</p>
<h1 align="center">thirdweb Contracts</h1>
<p align="center"><strong>Next iteration of thirdweb smart contracts. Install hooks in core contracts.</strong></p>
<br />

> :mega: **Call for feedback**: This design update is WIP and we encourage opening an issue with feedback.

### Benchmarks

**ERC-721 Core Benchmarks** ([test/ERC721CoreBenchmarks.t.sol](https://github.com/thirdweb-dev/contracts-next/blob/main/test/ERC721CoreBenchmarks.t.sol))
| Action | Gas consumption |
| ------------- | ------------- |
| Deploy (developer-facing) | 196_434 |
| Mint 1 token | 159_853 |
| Mint 10 tokens | 379_873 |
| Transfer token | 22_967 |
| Install 1 hook | 63_814 |
| Install 5 hooks | 73_395 |
| Uninstall 1 hook | 2_495 |
| Uninstall 5 hooks | 3_338 |
| Beacon upgrade (via platform) | 30_313 |

**ERC-721 Benchmarks Comparison** ([test/erc721-comparison/](https://github.com/thirdweb-dev/contracts-next/tree/main/test/erc721-comparison))
| Action | Thirdweb | Zora | Manifold |
| ------------- | ------------- | ------------- | ------------- |
| Deploy (developer-facing) | 191_902 | 477_739 | 299_526 |
| Claim 1 token | 160_798 | 151_865 | 175_723 |
| Transfer token | 23_230 | 37_354 | 29_255 |
| Setup token metadata | 114_045 | 31_946 | 14_205 |

# Design Overview

Developers deploy non-upgradeable minimal clones of token core contracts e.g. the ERC-721 Core contract.

- This contract is initializable, and meant to be used with proxy contracts.
- Implements the token standard (and the respective token metadata standard).
- Uses the role based permission model of the [`Permission`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/extension/Permission.sol) contract.
- Implements the [`TokenHookConsumer`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/extension/TokenHookConsumer.sol) interface.

Core contracts are deliberately written as non-upgradeable foundations that contain minimal code with fixed behaviour. These contracts are meant to be extended by developers using hooks.

## Hooks and Modularity

![mint tokens via hooks](https://ipfs.io/ipfs/QmXfN8GFsJNEgkwa9F44kRWFFnahPbyPb8yV2L9LmFomnj/contracts-next-mint-tokens.png)

Hooks are an external call made to a contract that implements the [`TokenHook`](https://github.com/thirdweb-dev/contracts-next/blob/main/src/extension/TokenHook.sol) interface.

The purpose of hooks is to allow developers to extend their contract's functionality by running custom logic right before a token is minted, transferred, burned, or approved, or for returning a token's metadata or royalty info.

There is a fixed, defined set of 6 hooks:

- **BeforeMint**: called before a token is minted in the ERC721Core.mint call.
- **BeforeTransfer**: called before a token is transferred in the ERC721.transferFrom call.
- **BeforeBurn**: called before a token is burned in the ERC721.burn call.
- **BeforeApprove**: called before the ERC721.approve call.
- **Token URI**: called when the ERC721Metadata.tokenURI function is called.
- **Royalty**: called when the ERC2981.royaltyInfo function is called.

Developers can install hooks into their core contracts, and uninstall hooks at any time. On installation, a hook contract tells the hook consumer which hook functions it implements -- the hook consumer maps all these hook functions to the mentioned hook contract as their implemention.

## Upgradeability

![beacon upgrade](https://ipfs.io/ipfs/QmS1zU629FoDZM1X3oRmMZyxi7ThW2UiFybK7mkpZ2DzBS/contracts-next-beacon-upgrade.png)

thirdweb will publish upgradeable, 'shared state' hooks for developers (see [src/erc721/hooks/](https://github.com/thirdweb-dev/contracts-next/tree/main/src/erc721/hooks) and [test/hook-examples](https://github.com/thirdweb-dev/contracts-next/tree/main/test/hook-examples) which contains the familiar Drop and Signature Mint contracts as shared state hooks).

These hook contracts are designed to be used by develpers as a shared resource, and are upgradeable by thirdweb. This allows thirdweb to make beacon upgrades to developer contracts using these hooks.

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

## Feedback

If you have any feedback, please create an issue or reach out to us at support@thirdweb.com.

## Authors

- [thirdweb](https://thirdweb.com)

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt)
