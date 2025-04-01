## Documentation

Primus tip contracts.

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

### Deploy & UpgrateAble

```shell
# Deploy
forge script script/DeployScript.s.sol --rpc-url $RPC_URL --broadcast

# Upgrade
forge script script/UpgradeScript.s.sol --rpc-url $RPC_URL --broadcast
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
