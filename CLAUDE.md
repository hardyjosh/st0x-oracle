# CLAUDE.md - ST0x Oracle Development Guide

## Project Overview

Solidity oracle adapter system that bridges Pyth Network price feeds to DeFi lending protocols (Morpho Blue, Aave V3, Compound V3). Two-layer architecture: oracle adapters (price source) and protocol adapters (protocol-specific interface).

## Build & Test

```bash
forge build          # Compile contracts
forge test           # Run all tests
forge test -vvv      # Verbose test output
forge fmt            # Format Solidity code
forge fmt --check    # Check formatting without modifying
```

## Architecture (Two Layers)

**Oracle Layer** — canonical price source per asset, implements `AggregatorV3Interface` (8 decimals):
- `PythOracleAdapter` — fetches from Pyth, scales to 8 decimals, has governance (pause, setPriceId, setMaxAge)

**Protocol Layer** — indirection so oracle swaps don't require protocol governance:
- `PassthroughProtocolAdapter` — for Aave/Compound/any Chainlink-compatible protocol, passes through `AggregatorV3Interface`
- `MorphoProtocolAdapter` — implements Morpho's `IOracle.price()`, scales 8→36 decimals

**Deployers** — beacon proxy pattern per `st0x.deploy`:
- Each contract type has a `BeaconSetDeployer` that owns a beacon and deploys proxies
- `OracleUnifiedDeployer` orchestrates deploying oracle + all protocol adapters for a new asset

## Key Design Decisions

- **No stored Pyth address**: Use `LibPyth.getPriceFeedContract(block.chainid)` at runtime (from `rain.pyth`)
- **AggregatorV3Interface as boundary**: Industry standard between oracle and protocol layers
- **Beacon proxies**: All instances share implementations, upgradeable via beacon owner
- **All governance on oracle layer**: Protocol adapters only have `setOracle()` admin function
- **Two protocol adapter contracts, not three**: `PassthroughProtocolAdapter` serves Aave, Compound, and any future Chainlink-compatible protocol via separate proxy instances

## Repository Structure

```
src/
├── concrete/
│   ├── oracle/
│   │   └── PythOracleAdapter.sol          # Core oracle, AggregatorV3Interface
│   ├── protocol/
│   │   ├── MorphoProtocolAdapter.sol      # IOracle, scales 8→36
│   │   └── PassthroughProtocolAdapter.sol # AggregatorV3Interface passthrough
│   └── deploy/
│       ├── PythOracleAdapterBeaconSetDeployer.sol
│       ├── MorphoProtocolAdapterBeaconSetDeployer.sol
│       ├── PassthroughProtocolAdapterBeaconSetDeployer.sol
│       └── OracleUnifiedDeployer.sol
└── lib/
    └── LibProdDeploy.sol
```

## Dependencies

- `rain.pyth` — `LibPyth.getPriceFeedContract()` and price feed ID constants
- `pyth-sdk-solidity` — `IPyth`, `PythStructs`
- `openzeppelin-contracts` — `UpgradeableBeacon`, `BeaconProxy`, `Initializable`, `AccessControl`

## Security Rules

- Pyth prices can be negative — always revert on `answer <= 0`
- Scaling math must not overflow — use checked arithmetic
- `maxAge` must be enforced on every price read
- Pause mechanism for corporate actions (splits, dividends)
- All admin roles held by founder multisig, no role separation

## Conventions

- Follow Foundry/forge-std conventions for tests
- Contract names match filenames exactly
- Use `I_` prefix for immutable beacon references (e.g., `I_PYTH_ORACLE_ADAPTER_BEACON`)
- Initializable pattern for proxy contracts (not constructors for state)
- Full spec is in `SPEC.md` — refer to it for detailed implementation guidance
