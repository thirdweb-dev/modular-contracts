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

<image src="https://d391b93f5f62d9c15f67142e43841acc.ipfscdn.io/ipfs/bafybeiekqr3xscf6glbzhowpwwj52nk2bjxu3itkoped2ybcoo2roclf3q/contracts-next-mint-tokens.png" />
