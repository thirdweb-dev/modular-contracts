<p align="center">
<br />
<a href="https://thirdweb.com"><img src="https://github.com/thirdweb-dev/typescript-sdk/blob/main/logo.svg?raw=true" width="200" alt=""/></a>
<br />
</p>
<h1 align="center">thirdweb Contracts-Next</h1>
<p align="center"><strong>Next iteration of thirdweb smart contracts. Install hooks in core contracts.</strong></p>
<br />

> :mega: **Call for feedback**: These contracts are NOT AUDITED. This design update is WIP and we encourage opening an issue with feedback.

# Run this repo

Clone the repo:

```bash
git clone https://github.com/thirdweb-dev/contracts-next.git
```

Install dependencies:

If you are in the root directory of the project, run:

```bash
# Install dependecies for core contracts
forge install --root ./core

# Install dependecies for hooks contracts
forge install --root ./hooks
```

If you are in `/core`:

```bash
# Install dependecies for core contracts
forge install
```

If you are in `/hooks`:

```bash
# Install dependecies for hooks contracts
forge install
```

From within `/contracts`, run benchmark comparison tests:

```bash
# create a wallet for the benchmark (make sure there's enough gas funds)
cast wallet import testnet -i

# deploy the benchmark contracts and perform the tests
forge script script/benchmark-ext/erc721/BenchmarkERC721.s.sol --rpc-url "https://sepolia.rpc.thirdweb.com" --account testnet [--broadcast]
```

From within `/contracts`, run gas snapshot:

```bash
forge snapshot --isolate --mp 'test/benchmark/*'
```

## Usage

You can find testnet deployments of this hooks design setup, and JS scripts to interact with an ERC-721 core contract and its hooks here: https://github.com/thirdweb-dev/contracts-next-scripts

# Benchmarks

### ERC-721 Core Benchmarks via transactions on Goerli

| Action                                      | Gas consumption | Transaction                                                                                              |
| ------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------- |
| Mint 1 token (token ID `0`)                 | 145_373         | [ref](https://goerli.etherscan.io/tx/0x1de1431200f6d39e9f4ddba3386e413078308a6eae1ebcc722884443b643d7d0) |
| Mint 1 token (token ID `>0`)                | 116_173         | [ref](https://goerli.etherscan.io/tx/0xc38e82228a1f8cf877abfeeb28e3f294bb38b90f51cbb2df1c899f03fad4e355) |
| Mint 10 tokens (including token ID `0`)     | 365_414         | [ref](https://goerli.etherscan.io/tx/0x1e8a79bd1806a3410a46f8d0ec0fcff099e3aeff6d4e64815c1f400ab092c77e) |
| Mint 10 tokens (not including token ID `0`) | 331_214         | [ref](https://goerli.etherscan.io/tx/0xe4ab2650f8827d52d2ec15956da910915b2b08f67d3f59ac8091da2fbd0369a0) |
| Transfer token                              | 64_389          | [ref](https://goerli.etherscan.io/tx/0x3ca2c4c74d6c8a4859fd78af5091c4dc4dc0fc0452202b18b611e4f0308c3673) |
| Install 1 hook                              | 105_455         | [ref](https://goerli.etherscan.io/tx/0x8df68fefe6f0318220795f4c56aec81fdafea2a3d17da2d45a0a762aac6cf6d0) |
| Install 5 hooks                             | 191_918         | [ref](https://goerli.etherscan.io/tx/0x184f59ce6f83a6927e2269879bdec9ccd29f8ed3fd98be9d4d359e34cfde4ce5) |
| Uninstall 1 hook                            | 43_468          | [ref](https://goerli.etherscan.io/tx/0x30c678277603c80b1f412049b13ba6742712c64ef9973b00d8866169589ad40f) |
| Uninstall 5 hooks                           | 57_839          | [ref](https://goerli.etherscan.io/tx/0xf1869d1b6fdc0f7e340cd30df2f0b57408cf0d752e4898ef14836a7672877050) |

**Note:**

- 'Minting tokens' benchmarks use the `AllowlistMintHook` contract as the `beforeMint` hook. All token minting benchmarks include distributing non-zero primary sale value and platform fee.
- All hooks used in these benchmarks are minimal clone proxy contracts pointing to hook contract implementations.

### ERC-721 Contracts Benchmarks Comparison via transactions on Sepolia

| Action                    | Thirdweb (Hooks)                                                                                                 | Thirdweb Drop                                                                                                    | Zora                                                                                                             | Manifold                                                                                                         |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Deploy (developer-facing) | 213_434 [tx](https://sepolia.etherscan.io/tx/0x4899fd74e09b4994162f0ce4ea8783a93712825cb20373612263cbfcf83137dc) | 719_842 [tx](https://sepolia.etherscan.io/tx/0x69bf0d597b4db864d50b1c592451156e23a0eca598fd337f0888f3f0d45eda85) | 499_968 [tx](https://sepolia.etherscan.io/tx/0x1d3e653ab587f3203abdcb233ca3502f5a99b2ba38c62b9097b4d9cecac39016) | 232_917 [tx](https://sepolia.etherscan.io/tx/0x80fcff853e07bb99475e0258c315eaf4f91f6e954f9edc170e05a833568401d3) |
| Claim 1 token             | 149_142 [tx](https://sepolia.etherscan.io/tx/0xce9155496a5e1705fd91e25fa5c4b6a2664ee8951010e0d236b8f1bc1bebb2a9) | 196_540 [tx](https://sepolia.etherscan.io/tx/0xd2d5eaa191ebe342f34a2647a253782795d93cecc90ae0e3de4bb6a6afe29d0a) | 160_447 [tx](https://sepolia.etherscan.io/tx/0xe1b431c28f0cc8d03489ea1a54fb6b70eea4dc0210cbf24f9cf6b22c3a68f99d) | 184_006 [tx](https://sepolia.etherscan.io/tx/0x149ac1f2aec78753f73a7b16bdea9dd81dc5823893a128422499ba49af3b07f4) |
| Transfer token            | 59_587 [tx](https://sepolia.etherscan.io/tx/0x252311fc0ada4873d8fcc036ec7145b1dfb76bef7d974aae15111623cf4e889b)  | 76_102 [tx](https://sepolia.etherscan.io/tx/0xd5dd3f3f33e6755fd07617795a382e7e34005771a6374dacbfb686c6b4d981cc)  | 71_362 [tx](https://sepolia.etherscan.io/tx/0x4f3d79e1b5582ebab5ff6e1f343d640b2e47ded458223de4e1cf248f1c72776d)  | 69_042 [tx](https://sepolia.etherscan.io/tx/0xb3eb80ea9cf88d3a731490f6c9fd8c3f9d8b8283e5b376e4aaf001fb46e84ae2)  |
| Setup token metadata      | 60_217 [tx](https://sepolia.etherscan.io/tx/0xfe99caf84e543f1b73055da7ef23f8071d3b8d893c838c12b9b3567f0a4cdcb8)  | 47_528 [tx](https://sepolia.etherscan.io/tx/0x6526f514b47d60785eb3951046dc1e30b175d2aa74aa2693932ea68ed2054d4d)  | 54_612 [tx](https://sepolia.etherscan.io/tx/0xd959c6dfc531994bca58df41c30952a04a6f1ab7e86b3ab3457ed4f4d5bd1846)  | 29_789 [tx](https://sepolia.etherscan.io/tx/0x1d3e653ab587f3203abdcb233ca3502f5a99b2ba38c62b9097b4d9cecac39016)  |

# Design Overview: Hooks architecture

The _Hooks architecture_ contains two types of smart contracts:

1. **Core contract**

   A minimal, non-upgradeable smart contract that contains functions and state/storage that are core to the contract’s identity.

2. **_Hook_ contract**

   A stateful, upgradeable or non-upgradeable smart contract meant to be _installed_ into a core contract. It contains fixed number of pre-defined hook functions that are called during the execution of a core contract’s functions.

![Hooks-architecture-overview](https://github.com/thirdweb-dev/contracts-next/blob/main/assets/hooks-banner.png?raw=true)

The goal of this _Hooks architecture_ is making upgradeability **_safer_**, **_more predictable and less likely to go wrong_** by giving developers:

- An API that contains a comprehensive, but fixed number of pre-defined points in a smart contract where developers can introduce customizations.
- Separation of state and logic that’s core to their contract, from state and logic that is ancillary i.e. providing assistance in updating the core state of the contract. (Core vs. Hook)

Core contracts are always non-upgradeable. However, considering a core contract and its _hooks_ together as one system — the _Hooks architecture_ allows for 3 different kinds of upgradeability setups:

- **Non-upgradeable**: Developer contracts are not upgradeable.
- **Self-managed upgradeable:** Only the developer is authorized to upgrade their (hook) contracts.
- **Managed upgradeable:** Developer authorizes a third party to upgrade their (hook) contracts.

## Token contracts in the Hooks architecture

We write one core contract implementation for each token type (ERC-20, ERC-721, ERC-1155). Developers deploy a token core contract for themselves and _install_ hooks into it.

All 3 token core contracts implement:

- The token standard itself. ([ERC-20](https://eips.ethereum.org/EIPS/eip-20) + [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612) Permit / [ERC-721](https://eips.ethereum.org/EIPS/eip-721) / [ERC-1155](https://eips.ethereum.org/EIPS/eip-1155)).
- [HookInstaller](https://github.com/thirdweb-dev/contracts-next/blob/main/src/core/src/interface/IHookInstaller.sol) interface for installing hooks.
- A token standard specific `getAllHooks()` view function interface (e.g. [IERC20HookInstaller](https://github.com/thirdweb-dev/contracts-next/blob/main/src/core/src/interface/IERC20HookInstaller.sol))
- [EIP-173](https://eips.ethereum.org/EIPS/eip-173) Contract ownership standard
- [EIP-7572](https://eips.ethereum.org/EIPS/eip-7572) Contract-level metadata via `contractURI()` standard
- Multicall interface
- External mint() and burn() functions.

The token core contracts use the [solady implementations](https://github.com/Vectorized/solady) of the token standards, ownable and multicall contracts.

### Available hooks for token contracts

| **Hook Functions**                   | ERC-20                                                                    | ERC-721                                                                                                   | ERC-1155                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| beforeApprove (Approve)              | ✅ called before a token is approved in the `ERC20Core.approve` call.     | ✅ called before a token is approved in the `ERC721Core.approve` and `ERC721.setApprovalForAll` calls.    | ✅ called before a token is approved in the `ERC1155.setApprovalForAll` call.                               |
| beforeBurn (Burn)                    | ✅ called before a token is burned in the `ERC20.burn` call.              | ✅ called before a token is burned in the `ERC721.burn` call.                                             | ✅ called before a token is burned in the `ERC1155.burn` call.                                              |
| beforeMint (Minting)                 | ✅ called before a token is minted in the `ERC20Core.mint`                | ✅ called before a token is minted in the `ERC721Core.mint`                                               | ✅ called before a token is minted in the `ERC1155Core.mint`                                                |
| beforeTransfer (Transfer)            | ✅ called before a token is transferred in the `ERC20.transferFrom` call. | ✅ called before a token is transferred in the `ERC721.transferFrom` and `ERC721.safeTransferFrom` calls. | ✅ called before a token is transferred in the `ERC1155.transferFrom` and `ERC1155.safeTransferFrom` calls. |
| beforeBatchTransfer (Batch Transfer) | ❌                                                                        | ❌                                                                                                        | ✅ called once before a batch transfer of tokens in the `ERC1155.safeBatchTransferredFrom` call.            |
| onRoyaltyInfo (EIP-2981 Royalty)     | ❌                                                                        | ✅ Called to retrieve royalty info on `EIP2981.royaltyInfo` call                                          | ✅ Called to retrieve royalty info on `EIP2981.royaltyInfo` call                                            |
| onTokenURI (Token Metadata)          | ❌                                                                        | ✅ Called to retrieve the metadata for a token on an `ERC721Metadata.tokenURI` call                       | ✅ Called to retrieve the metadata URI for a token on a `ERC1155Metadata.uri` call                          |

## Feedback

If you have any feedback, please create an issue or reach out to us at support@thirdweb.com.

## Authors

- [thirdweb](https://thirdweb.com)

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt)
