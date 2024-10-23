# SuperChain ERC20 Module
The contracts and scripts in this folder help setup and run the integration testing of the SuperChainInterop module with supersim

#### IL2ToL2CrossDomainMessenger.sol
Interface for the L2 to L2 cross domain messenger

#### SuperChainBridge.sol
Proof of concept SuperChain Bridge that contains `sendERC20` function and `relayERC20` function

#### SuperChainERC20Setup.s.sol
Script that deterministically deploys the `SuperChainBridge` and `SuperChainERC20` contract
(which is composed of the `ERC20Core` and `SuperChainInterop` module)

#### SuperChainInterop.s.sol
Script that mints tokens on the L2 and calls `sendERC20` on the SuperChainBridge contract

# How to run the integration test
1. Start supersim with the autorelayer enabled.
```
supersim --interop.autorelay
```

2. Deploy the SuperChainBridge and SuperChainERC20 contracts on both chains 901 and 902
Take note of the SuperChainBridge and Core addresses on both chains
```
# deploys to chain 901
forge script --chain 901 script/superchain/SuperChainERC20Setup.s.sol:SuperChainERC20SetupScript --rpc-url http://127.0.0.1:9545 -vvvv --broadcast --evm-version cancun

# deploys to chain 902
forge script --chain 902 script/superchain/SuperChainERC20Setup.s.sol:SuperChainERC20SetupScript --rpc-url http://127.0.0.1:9546 -vvvv --broadcast --evm-version cancun
```

3. Mint and sent tokens through the superchain
```
forge script --chain 901 script/superchain/SuperChainInterop.s.sol:SuperChainInteropScript --rpc-url http://127.0.0.1:9545 -vvvv --broadcast --evm-version cancun
```

4. Check the balance of SuperChainERC20 for the test account
```
cast balance --erc20 <CORE_ADDRESS> 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:9546
```

