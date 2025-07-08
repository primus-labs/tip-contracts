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

### Compile and upload SPF program

```sh
# Compile the SPF library
LLVM_DIR=PATH/TO/LLVM/BINARIES make

# Upload the compiled program to the SPF server. This will return an identifier that
# should match the PRIMUS_TIP_SPF_LIBRARY value in `src/PrimusFHETip.sol`. We
# add a 0x prefix to the hash to make it a valid address.
curl -X POST https://spf.sunscreen.tech/programs --data-binary @fhe-programs/compiled/primus-fhe | tr -d '"' | sed 's/^/0x/'
```
