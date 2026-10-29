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

Primus Tip Contracts are deployed on BNB Smart Chain (BSC) and other EVM-compatible chains like Base, Pharos and Monad, enabling zktls proof on user social handles and tipping feature.

- Network: BNB Smart Chain
- Chain ID: 56
- Transfer Contract Address: 0x1fb86db904caf7c12100ea64024e5dfd7505e484
- Red Pocket Contract Address: 0x083693c148e30b3a231d325366e76b38293fca10

### Query and transfer owners

Both contracts have a business owner on the proxy and an upgrade owner on
their respective ProxyAdmin. The scripts discover ProxyAdmin addresses from
the ERC-1967 admin slot. Run against the network where the proxies are deployed.

```sh
export RPC_URL="https://your-rpc-endpoint"
export TIP_PROXY_ADDRESS="0x..."
export RED_ENVELOPE_PROXY_ADDRESS="0x..."

# Read all four owners and both fee recipients; no private key required.
forge script script/QueryOwners.s.sol:QueryOwners --rpc-url "$RPC_URL"

# Transfer all four owners to the same address.
# Set PRIVATE_KEY securely in your environment or local .env file.
# Both business owners must match this key's address (or already be NEW_OWNER).
export NEW_OWNER="0x..."
# If upgrade ownership uses a different account, also securely set
# PROXY_ADMIN_PRIVATE_KEY; otherwise it defaults to PRIVATE_KEY.

# Simulate first (no transactions sent).
forge script script/TransferOwners.s.sol:TransferOwners --rpc-url "$RPC_URL"

# Send the transfers after reviewing the simulation.
forge script script/TransferOwners.s.sol:TransferOwners --rpc-url "$RPC_URL" --broadcast --slow

# Verify the actual on-chain owners after broadcasting.
forge script script/QueryOwners.s.sol:QueryOwners --rpc-url "$RPC_URL"
```

Transfers take effect immediately and do not change `feeRecipient`. All four
owners are checked before any transfer; both ProxyAdmin owners must match the
admin key's address (or already be `NEW_OWNER`). The broadcast consists of up to
four separate transactions, not an atomic batch. If interrupted, query the owners
and rerun: targets already owned by `NEW_OWNER` are skipped. The transfer script's
final output describes simulated state; use the query script to confirm chain state.

On Monad, Foundry's local gas estimate can be lower than the chain requires.
If a proxy transfer fails with `out of gas`, rerun the script with a larger
estimate multiplier. Already transferred owners are skipped, so a fresh run
only sends the remaining transfers (do not use `--resume` to resend transactions
with the old gas limits):

```sh
forge script script/TransferOwners.s.sol:TransferOwners --rpc-url monad --broadcast --slow --gas-estimate-multiplier 200
forge script script/QueryOwners.s.sol:QueryOwners --rpc-url monad
```

The multiplier is a percentage (`200` means twice the local estimate). Monad
charges based on the transaction's gas limit, so avoid unnecessarily large
limits. See [Monad gas pricing](https://docs.monad.xyz/developer-essentials/gas-pricing).

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
