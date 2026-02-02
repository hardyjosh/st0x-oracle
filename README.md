# st0x.oracle

Oracle adapter system that bridges Pyth Network price feeds to DeFi lending protocols (Morpho Blue, Aave V3, Compound V3). Two-layer architecture separates oracle adapters (price source) from protocol adapters (protocol-specific interface), allowing independent upgrades and oracle swaps without protocol governance.

## Architecture

```
PROTOCOL ADAPTERS (indirection layer)

┌─────────────────────┐  ┌──────────────────────────────────┐
│ MorphoProtocolAdapter│  │ PassthroughProtocolAdapter       │
│ IOracle (8→36 dec)  │  │ (instances: Aave, Compound, ...) │
│                     │  │ AggregatorV3Interface passthrough │
└─────────┬───────────┘  └──────────────┬───────────────────┘
          └──────────┬──────────────────┘
                     ▼
          ┌─────────────────────┐
          │ AggregatorV3Interface│  ← contract boundary
          └─────────────────────┘
                     ▲
          ┌──────────┴──────────┐
          ▼                     ▼
┌─────────────────┐   ┌─────────────────┐
│PythOracleAdapter│   │ Future adapters │
│ Pyth → 8 dec    │   │ (Chainlink etc) │
│ pause, admin    │   │                 │
└─────────────────┘   └─────────────────┘

ORACLE ADAPTERS (canonical price source per asset)
```

**Oracle layer** -- one `PythOracleAdapter` per asset, implements `AggregatorV3Interface` at 8 decimals. Governance controls (pause for corporate actions) live here.

**Protocol layer** -- `PassthroughProtocolAdapter` (Aave/Compound/any Chainlink-compatible) and `MorphoProtocolAdapter` (scales 8 to 36 decimals). Each has `setOracle()` so the underlying oracle can be swapped without touching protocol config.

**Deployers** -- beacon proxy pattern via `st0x.deploy`. `OracleUnifiedDeployer` orchestrates deploying an oracle adapter + all protocol adapters for a new asset in one call.

## Setup

This project uses Nix flakes for reproducible toolchain management.

```bash
nix develop
```

## Build & Test

```bash
forge build
forge test
forge test -vvv          # verbose
forge fmt --check        # check formatting
```

Fork tests require a Base RPC URL:

```bash
export RPC_URL_BASE_FORK=<your-base-rpc-url>
forge test
```

## Repository Structure

```
src/
├── concrete/
│   ├── oracle/
│   │   └── PythOracleAdapter.sol
│   ├── protocol/
│   │   ├── MorphoProtocolAdapter.sol
│   │   └── PassthroughProtocolAdapter.sol
│   └── deploy/
│       ├── PythOracleAdapterBeaconSetDeployer.sol
│       ├── MorphoProtocolAdapterBeaconSetDeployer.sol
│       ├── PassthroughProtocolAdapterBeaconSetDeployer.sol
│       └── OracleUnifiedDeployer.sol
├── interface/
│   └── IAggregatorV3.sol
└── lib/
    └── LibProdDeploy.sol
test/
├── abstract/
│   └── PythOracleAdapterTest.sol
├── lib/
│   └── LibFork.sol
└── src/
    └── concrete/
        ├── deploy/
        ├── oracle/
        └── protocol/
```

## Dependencies

- [rain.pyth](https://github.com/rainlanguage/rain.pyth) -- `LibPyth.getPriceFeedContract()` and price feed ID constants
- [pyth-sdk-solidity](https://github.com/pyth-network/pyth-sdk-solidity) -- `IPyth`, `PythStructs`
- [st0x.deploy](https://github.com/S01-Issuer/st0x.deploy) -- `BeaconSetDeployer` pattern, `ICloneableV2`
- [openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) -- `UpgradeableBeacon`, `BeaconProxy`, `Initializable`

## License

DCL-1.0
