<p align="center">
<br />
<a href="https://thirdweb.com"><img src="https://github.com/thirdweb-dev/typescript-sdk/blob/main/logo.svg?raw=true" width="200" alt=""/></a>
<br />
</p>
<h1 align="center">Modular Contracts</h1>
<p align="center"><strong>Write smart contracts for which you can add, remove, upgrade or switch out the exact parts you want.</strong></p>
<br />

A Modular Contract is built of two kinds of parts: a _Modular Core_ and its _Modular Extensions_.

![modular-contracts-analogy](./assets/readme-hero-image.png)

A developer writes a **_Core_** smart contract as the foundation that can be customized by adding new parts and updating or removing these parts over time. These ‘parts’ are **_Extension_** smart contracts which any third-party developer can independently develop with reference to the **_Core_** smart contract as the known foundation to build around.

# Install and Use

This project can currently be installed as a dependency in [foundry](https://book.getfoundry.sh/) projects. To install, run:

```bash
forge install https://github.com/thirdweb-dev/modular-contracts
```

Add the following in a `remappings.txt` file:

```
@modular-contracts/=lib/modular-contracts/src/
```

Import `ModularCore` inherit to build a Modular Core contract (e.g. ERC-721 Core):

```solidity
import {ModularCore} from "@modular-contracts/ModularCore.sol";
import {ERC721A} from "@erc721a/extensions/ERC721AQueryable.sol";

contract ModularNFTCollection is ERC721A, ModularCore {}
```

Import `ModularExtension` to create an Extension for your Core contract (e.g. `Soulbound`):

```solidity
import {ModularExtension} from "@modular-contracts/ModularExtension.sol";

contract SoulboundERC721 is ModularExtension {}
```

# Run this repo

Clone the repo:

```bash
git clone https://github.com/thirdweb-dev/modular-contracts.git
```

Install dependencies:

```bash
# Install dependecies
forge install
```

<!-- From within `/contracts`, run benchmark comparison tests:

```bash
# create a wallet for the benchmark (make sure there's enough gas funds)
cast wallet import testnet -i

# deploy the benchmark contracts and perform the tests
forge script script/benchmark-ext/erc721/BenchmarkERC721.s.sol --rpc-url "https://sepolia.rpc.thirdweb.com" --account testnet [--broadcast]
```

From within `/contracts`, run gas snapshot:

```bash
forge snapshot --isolate --mp 'test/benchmark/*'
``` -->

# Feedback

If you have any feedback, please create an issue or reach out to us at support@thirdweb.com.

# Authors

- [thirdweb](https://thirdweb.com)

# License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt)
