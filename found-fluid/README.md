## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


# 1. Deploy contracts
forge script script/DeployTradeExecutor.sol --rpc-url $RPC --broadcast -vvvv
forge script script/DeployFluidFlowFactory.sol --rpc-url $RPC --broadcast -vvvv

# 2. Create a fund
export FACTORY_ADDRESS=0x...
export TRADE_EXECUTOR=0x...
forge script script/CreateFund.sol --rpc-url $RPC --broadcast -vvvv

# 3. Execute sample trade
forge script script/ExecuteTrade.sol --rpc-url $RPC --broadcast -vvvv