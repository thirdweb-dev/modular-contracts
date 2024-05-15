<p align="center">
<br />
<a href="https://thirdweb.com"><img src="https://github.com/thirdweb-dev/typescript-sdk/blob/main/logo.svg?raw=true" width="200" alt=""/></a>
<br />
</p>
<h1 align="center">Design Document: Modular Contracts</h1>
<br />

# Technical Design

## Abstract

This architecture standardizes how a router contract verifies that an implementation contract is safe and compatible as a call destination for a given set of functions.

The architecture outlines interfaces for router contracts and implementation contracts that let them communicate and agree over compatibility with each other, and interfaces for ERC-165 compliance by router contracts.

## Motivation

Router contracts (i.e. contracts with a potentially different call destination per function) have gained adoption for their quality of being future-proof and upgradeable in parts.

There are various different ways to write router or implementation contracts, which means using any given implementation contract as a call destination in any given router contract can lead to either contract not operating according to its specification.

The goal of this architecture is to make all router and implementation contracts interoperable by creating a method where both contracts communicate and agree over compatibility before a router sets some implementation contract as the call destination for a set of functions.

The ecosystem benefits from this standardization as

- developers can safely re-use any self or third-party developed features (implementation contracts) across many projects (router contracts).
- new feature innovations (implementation contracts) can explicitly break compatibility with older, already deployed projects (router contracts).

## Specification

> The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “NOT RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119 and RFC 8174.

### Definitions

- **Router**: a smart contract with a potentially different call destination per function
- **Implementation**: a smart contract stored by a router contract as the call destination a given set of functions.
- **Modular Core:** a router contract written in the Modular Contract architecture and expresses compatibility with certain implementation contracts. Also referenced as “Core”.
- **Modular Extension**: an implementation contract written in the Modular Contract architecture and expresses compatibility with certain router contracts. Also referenced as “Extension”.

### Extension Config

The `ExtensionConfig` struct contains all information that a Core uses to check whether an Extension is compatible for installation.

**`ExtensionConfig` struct**

| Field                        | Type               | Description                                                                                                                           |
| ---------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| requiredInterfaceId          | bytes4             | The ERC-165 interface that a Core MUST support to be compatible for installation. (OPTIONAL field)                                    |
| registerInstallationCallback | bool               | Whether the Extension expects onInstall and onUninstall callback function calls at installation and uninstallation time, respectively |
| supportedInterfaces          | bytes4[]           | The ERC-165 interfaces that a Core supports upon installing the Extension.                                                            |
| callbackFunctions            | CallbackFunction[] | List of callback functions that the Core MUST call at some point in the execution of its fixed functions.                             |
| fallbackFunction             | FallbackFunction[] | List of functions that the Core MUST call via its fallback function with the Extension as the call destination.                       |

**`FallbackFunction` struct**

| Field          | Type     | Description                                                                                                                           |
| -------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| selector       | bytes4   | The 4-byte selector of the function.                                                                                                  |
| callType       | CallType | The type of call to make to the function.                                                                                             |
| permissionBits | uint256  | Core’s fallback function MUST check that msg.sender has these permissions before performing a call on the Extension. (OPTIONAL field) |

**`CallbackFunction` struct**

| Field    | Type     | Description                               |
| -------- | -------- | ----------------------------------------- |
| selector | bytes4   | The 4-byte selector of the function.      |
| callType | CallType | The type of call to make to the function. |

**`CallType` enum**

| Value        | Description                                                        |
| ------------ | ------------------------------------------------------------------ |
| CALL         | Perform a regular call on the specified function in the Extension. |
| STATICCALL   | Perform a staticcall on the specified function in the Extension.   |
| DELEGATECALL | Perform a delegateCall on the specified function in the Extension. |

### Modular Core

A router contract MUST implement `IModularCore` and ERC-165 interfaces to comply with the Modular Contract architecture.

The `ERC165.supportsInterface` function MUST return true for all interfaces supported by the Core and the supported interfaces expressed in the ExtensionConfig of installed extensions.

```solidity
interface IModularCore is IExtensionConfig {
    /**
     *  @dev Whether execution reverts when the callback function is not implemented by any installed Extension.
     *  @param OPTIONAL Execution does not revert when the callback function is not implemented.
     *  @param REQUIRED Execution reverts when the callback function is not implemented.
     */
    enum CallbackMode {
        OPTIONAL,
        REQUIRED
    }

    /**
     *  @dev Struct representing a callback function called on an Extension during some fixed function's execution.
     *  @param selector The 4-byte function selector of the callback function.
     *  @param mode Whether execution reverts when the callback function is not implemented by any installed Extension.
     */
    struct SupportedCallbackFunction {
        bytes4 selector;
        CallbackMode mode;
    }

    /**
     *  @dev Struct representing an installed Extension.
     *  @param implementation The address of the Extension contract.
     *  @param config The Extension Config of the Extension contract.
     */
    struct InstalledExtension {
        address implementation;
        ExtensionConfig config;
    }

    /// @dev Returns all callback function calls made to Extensions at some point during a fixed function's execution.
    function getSupportedCallbackFunctions() external pure returns (SupportedCallbackFunction[] memory);

    /// @dev Returns all installed extensions and their respective extension configs.
    function getInstalledExtensions() external view returns (InstalledExtension[] memory);

    /**
     *  @dev Installs an Extension in the Core.
     *
     *  @param extensionContract The address of the Extension contract to be installed.
     *  @param data The data to be passed to the Extension's onInstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onInstall` callback function if Extension Config has registerd for installation callbacks.
     *  MUST revert if Core does not implement the interface required by the Extension, specified in the Extension Config.
     *  MUST revert if any callback or fallback function in the Extension's ExtensionConfig is already registered in the Core with another Extension.
     *
     *  MAY interpret the provided address as the implementation address of the Extension contract to install as a proxy.
     */
    function installExtension(address extensionContract, bytes calldata data) external payable;

    /**
     *  @dev Uninstalls an Extension from the Core.
     *
     *  @param extensionContract The address of the Extension contract to be uninstalled.
     *  @param data The data to be passed to the Extension's onUninstall callback function.
     *
     *  MUST implement authorization control.
     *  MUST call `onUninstall` callback function if Extension Config has registerd for installation callbacks.
     *
     *  MAY interpret the provided address as the implementation address of the Extension contract which is installed as a proxy.
     */
    function uninstallExtension(address extensionContract, bytes calldata data) external payable;
}

```

### Modular Extension

Any given callback function in the ExtensionConfig of an installed Extension MUST be called by the Core during the function execution of some fixed function.

Any given fallback function in the ExtensionConfig of an installed Extension MUST be called by the Core via its fallback, when called with the given fallback function’s calldata.

```solidity
interface IModularExtension is IExtensionConfig {
    /**
     *  @dev Returns the ExtensionConfig of the Extension contract.
     */
    function getExtensionConfig() external pure returns (ExtensionConfig memory);
}
```

## Rationale

### Callback and Fallback functions

We allow for a Core to be customized by Extension contracts in two different ways — callback functions and fallback functions.

Callback functions are function calls made to an Extension at some point during the execution of a fixed function. They allow injecting custom logic to run within a Core’s fixed functions. This means a Core can have a foundational API of fixed functions which can nevertheless enjoy customizations.

Fallback functions are functions that are callable on the Core as an entrypoint, whereon the Core calls an Extension from its fallback function with the calldata it receives. They allow additions to a Core’s foundational API of fixed functions.

### CallType for Callback and Fallback functions

An Extension expresses the call type for the callback and fallback functions specified in its ExtensionConfig.

This means that an Extension tells a Core whether to perform a call, delegateCall or staticcall on a given callback or fallback function, based on how the Extension contract is written and meant to be used.

For example, an Extension may be written a stateless logic contract, or a stateful shared contract where a Core — that has installed the Extension — is the msg.sender calling its relevant callback and fallback functions.

### Core and Extension compatibility

An Extension is compatible to install in a Core if:

1. all of the Extension’s callback functions (specified in ExtensionConfig) are included in the Core’s supported callbacks (specified in IModularCore.getSupportedCallbackFunctions).

   This is because we assume that an Extension only specifies a callback function in its ExtensionConfig when it expects a Core to call it.

2. the Core implements the required interface (if any) specified by the ExtensionConfig

   It is optional for an ExtensionConfig to specify an interface that a Core must implement. However, some Extensions may only be sensible to install in particular Core contracts, and the ExtensionConfig.requiredInterfaceId field encodes this requirement.

### Pure getter functions

Both IModularCore.getSupportedCallbackFunctions and IModularExtension.getExtensionConfig are pure functions, which means their return value does not change based on any storage.

For a given Extension, it is important for the Core’s stored representation of an ExtensionConfig to not go out of sync with the actual return value of IModularExtension.getExtensionConfig at any time, since this may lead to unintended consequences such as the Core calling functions on the Extension that no longer exist or be called on the Extension contract.

### Permissions in FallbackFunction and CallbackFunction structs

The FallbackFunction struct contains a `uint256 permissions` field that allows expressing the permissions required by the msg.sender in the Core contract’s fallback to be authorized for calling the relevant function on the Extension contract.

This is important because in case the fallback function’s call type is CALL, the Core contract itself is the msg.sender in the function called on the Extension contract and a caller should be authorized on the Core to use the Core contract itself as a caller.

Also in case the fallback function’s call type is DELEGATECALL, a caller should be authorized for making the state updates to the Core contract that’ll result from a delegateCall to the relevant Extension contract function.

The CallbackFunction struct does not contain a similar permissions struct field.

This is because a callback function call is specified in the function body of a fixed function, and so, the authorization a caller is left to the Core contract itself since it is expected that the Core will perform authorization checks on callers in its fixed functions, wherever necessary.

## Reference Implementation

### IModularCore

https://github.com/thirdweb-dev/modular-contracts/blob/jl/patch-7/core/src/ModularCore.sol

### IModularExtension

```solidity
contract MockExtension is IModularExtension {
    mapping(address => uint256) index;

    function increment() external {
			   index[msg.sender]++;
    }

    function getIndex() external view {
		    return index[msg.sender];
    }

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.callbackFunctions[0] = CallbackFunction(this.increment.selector, CallType.CALL);

        config.fallbackFunctions = new FallbackFunction()[1];
        config.fallbackFunctions[0] = FallbackFunction(this.getIndex.selector, CallType.STATICCALL, 0);
    }
}
```

## Security Considerations

### Upgradeability leading to Core out-of-sync with Extension

There are 4 upgradeability models possible in the Modular Contracts architecture:

| [Case-1] Immutable Core + Immutable Extension   | [Case-2] Upgradeable Core + Immutable Extension   |
| ----------------------------------------------- | ------------------------------------------------- |
| [Case-3] Immutable Core + Upgradeable Extension | [Case-4] Upgradeable Core + Upgradeable Extension |

In all 4 models, a Core and _installed_ Extension must maintain the following property:

> An installed Extension contract implements **_all and only_** the callback and fallback functions for which the Core has stored the Extension as the call destination.

The Extension contract expresses the callback and fallback functions it implements via its ExtensionConfig.

This property is important to avoid getting either of the two — Core or Extension — contracts into an “unintentional state” i.e. an update to contract storage that is not according to the contract’s intended specification.

1. **[Case-1]**

   This property is always satisfied since the return value of `getExtensionConfig` never changes in an immutable Extension contract, and the relevant storage of the Core only changes in expected ways in an `installExtension` or `uninstallExtension` call.

2. **[Case-2]**

   This property is at risk of not being satisfied when a Core contract with installed extensions is upgraded such that the `uninstallExtension` function updates state incorrectly, compared to its implementation prior to the upgrade.

3. **[Case-3] & [Case-4]**

   The property is at risk of not being satisfied whenever an Extension contract is upgradeable.

   This is because the `getExtensionConfig` return value can change for an Extension already installed in a Core, resulting in the config stored by the Core to go out-of-sync with the new config of the Extension, post upgrade.

   For example, an Extension contract upgrade may include an addition of a function that’s required to be called for the Extension to work according to its specification. This new function will be missing from a Core which installed the Extension contract pre upgrade.

## Token Core and Extension contracts.

thirdweb is rolling out the _Modular Contracts_ architecture with token Core contracts — ERC-20, ERC-721 and ERC-1155 Core contracts — and a set of commonly used features as Extensions.

![Core-Extension-Flow-Example](../assets/core-extension-flow-example.png)

All 3 token core contracts implement:

- The token standard itself. ([ERC-20](https://eips.ethereum.org/EIPS/eip-20) + [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612) Permit / [ERC-721](https://eips.ethereum.org/EIPS/eip-721) / [ERC-1155](https://eips.ethereum.org/EIPS/eip-1155)).
- `ModularCore` interface
- [EIP-7572](https://eips.ethereum.org/EIPS/eip-7572) Contract-level metadata via `contractURI()` standard
- Multicall interface
- External mint() and burn() functions.

The token core contracts use the [solady implementations](https://github.com/Vectorized/solady) of the token standards, ownable and multicall contracts.

### Mint, Burn and supported Callback functions per Token Standard

All callback functions accept the same arguments as the fixed function in which they are called.

The `mint` and `burn` functions in each Token Core Contract take in a bytes argument that is passed to their respective callback functions without mutating it.

This allows for passing custom arguments to the callback function to suit the handling of whichever Extension implements the callback function.

Additionally, the `mint` function passes any msg.value it receives in the function call.

**ERC-20 Core**

```solidity
function mint(address to, uint256 amount, bytes calldata data) external payable;

function burn(uint256 amount, bytes calldata data) external;
```

| Callback function   | Called in which ERC-20 Core function? | Required to be installed? |
| ------------------- | ------------------------------------- | ------------------------- |
| beforeMintERC20     | mint                                  | ✅                        |
| beforeBurnERC20     | burn                                  | ❌                        |
| beforeTransferERC20 | transferFrom                          | ❌                        |
| beforeApproveERC20  | approve                               | ❌                        |

**ERC-721 Core**

```solidity
function mint(address to, uint256 quantity, bytes calldata data) external payable;

function burn(uint256 tokenId, bytes calldata data) external;
```

| Callback function    | Called in which ERC-721 Core function? | Required to be installed? |
| -------------------- | -------------------------------------- | ------------------------- |
| beforeMintERC721     | mint                                   | ✅                        |
| beforeBurnERC721     | burn                                   | ❌                        |
| beforeTransferERC721 | transferFrom                           | ❌                        |
| beforeApproveERC721  | approve                                | ❌                        |
| beforeApproveForAll  | setApprovalForAll                      | ❌                        |
| onTokenURI           | tokenURI                               | ✅                        |

**ERC-1155 Core**

```solidity
function mint(address to, uint256 tokenId, uint256 value, bytes memory data) external payable;

function burn(address from, uint256 tokenId, uint256 value, bytes memory data) external;
```

| Callback function          | Called in which ERC-1155 Core function? | Required to be installed? |
| -------------------------- | --------------------------------------- | ------------------------- |
| beforeMintERC1155          | mint                                    | ✅                        |
| beforeBurnERC1155          | burn                                    | ❌                        |
| beforeTransferERC1155      | safeTransferFrom                        | ❌                        |
| beforeBatchTransferERC1155 | safeBatchTransferFrom                   | ❌                        |
| beforeApproveForAll        | setApprovalForAll                       | ❌                        |
| onTokenURI                 | tokenURI                                | ✅                        |

### Supported Token Extensions

thirdweb will roll out Token Core contracts with the following Extensions available for installation:

| Extension           | Category  | Description                                                                                                                             | Callback functions                                | Notable                                            | ERC-20 | ERC-721 | ERC-1155 |
| ------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------- | ------ | ------- | -------- |
| ClaimPhaseMint      | Minting   | distribute tokens under claim phase criteria.                                                                                           | beforeMint                                        | Platform fees supported                            | ✅     | ✅      | ✅       |
| SignatureMinting    | Minting   | mint tokens via a voucher issued by an authority.                                                                                       | beforeMint                                        | Platform fees supported                            | ✅     | ✅      | ✅       |
| Soulbound           | Transfers | optionally set all tokens as non-transferrable                                                                                          | beforeTransfer and beforeBatchTransfer (ERC-1155) |                                                    | ✅     | ✅      | ✅       |
| BatchUploadMetadata | Metadata  | single/batch upload NFT metadata                                                                                                        | onTokenURI                                        | Replaces legacy LazyMint extension contract.       | ❌     | ✅      | ✅       |
| OpenEditionMetadata | Metadata  | shared metadata (except unique tokenId) across all NFTs                                                                                 | onTokenURI                                        | Replaces legacy SharedMetadata extension contract. | ❌     | ✅      | ✅       |
| SimpleMetadata      | Metadata  | set metadata per NFT token ID                                                                                                           | onTokenURI                                        |                                                    | ❌     | ✅      | ✅       |
| Royalty             | Royalty   | EIP-2981 royalty. Set a default royalty percentage and recipient across all NFTs, or specific royalty percentage and recipient per NFT. | -                                                 |                                                    | ❌     | ✅      | ✅       |

## Handling Upgradeable Extensions

thirdweb has implemented the Modular Contracts architecture with upgradeability and permissions in mind.

`ModularCoreUpgradeable` is an implementation of the IModularCore interface that works with upgradeable Extension contracts, without compromising the security of the Core contract.

https://github.com/thirdweb-dev/modular-contracts/blob/jl/patch-7/core/src/ModularCoreUpgradeable.sol

1. The `ModularCoreUpgradeable.installExtension` function expects you to pass an address of an implementation/logic contract.
2. The Core contract then uses the canonical ERC1967 Factory to deploy an ERC-1967 proxy pointing to the provided extension *implementation* address.

   The "canonical ERC1967 Factory" is 0age's ImmutableCreate2Factory located at `0x0000000000FFe8B47B3e2130213B802212439497` on all EVM chains. Deployment instructions are [here on the Seaport github](https://github.com/ProjectOpenSea/seaport/blob/main/docs/Deployment.md).

3. The ERC-1967 ‘Extension Proxy’ contract is deployed using a deterministic salt and this same proxy contract address is maintained throughout all future upgrades of the underlying implementation contract of the Extension Proxy.

   This means that if the Extension Proxy contract is stateful (and not just a logic contract for the Core), its storage is not lost all throughout the time it is installed in the Core.

4. The upgrade admin of the Extension Proxy is the core contract, which means all implementation upgrades of the Extension Proxy happen via a call to the core contract (`updateExtension`, below) by a caller authorized on the core contract.
5. An upgrade of the Extension Proxy is performed by calling the `upgradeExtension` function:

   ```solidity
   /// @notice Updates the implementation of an Extension.
   function updateExtension(
   		address currentExtensionImplementation,
   		address newExtensionImplementation
   ) external;
   ```

   The Core contract requires an Extension’s implementation contract address to retrieve the Extension Proxy address, after which it can upgrade the Extension Proxy’s implementation to the provided new implementation address. After the upgrade, the Extension is identified on the Core via the new implementation address.

   This upgrade is sandwiched between:

   - BEFORE upgrade: Fetch the extension config from the Extension Proxy and delete all associated storage from the Core, as in uninstallation time.
   - AFTER upgrade: Re-fetch the extension config from the Extension Proxy and update the associated storage in Core, as in installation time.

   We do this because an upgrade may include changes to the return values of the `getExtensionConfig` function, and the Core contract's storage must be in sync with the Extension's new extension config.

So, from the perspective of an end user of the contract, they are providing an implementation address as an Extension to install, and they will later provide a new implementation address to update their extension, or the existing implementation address to uninstall their extension.

The end user / developer is always dealing with implementation contract addresses. This means that there is no "extension name", "extension ID" or "version" to identify a given Extension construct on the Core contract.

## Permission Model

`ModularCoreUpgradeable` uses role based permissions implementation of Solady’s [OwnableRoles](https://github.com/Vectorized/solady/blob/main/src/auth/OwnableRoles.sol), and follows [EIP-173: Contract Ownership Standard](https://eips.ethereum.org/EIPS/eip-173).

The contract owner can grant and revoke roles from other addresses.

In addition to the owner status, the contract contains `INSTALLER_ROLE`:

```solidity
uint256 public constant INSTALLER_ROLE = 1 << 0;
```

Either the contract owner, or a holder of this role is authorized to manage extension installation i.e. call `installExtension`, `updatedExtension` and `uninstallExtension`.

---

thirdweb is excited to bring developers the Modular Contract framework and take a step towards building an ecosystem of third-party developer smart contracts that lets developers earn money through code and lets builders discover and use the right smart contracts to build their use case.
