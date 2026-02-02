# 🔮 ST0x Oracle Adapters Specification

**Repository:** `st0x.oracle`
**Version:** 1.0
**Status:** Draft
**Date:** 2026-02-01

---

## 1. Problem Statement

ST0x tokenized equities need to integrate with DeFi lending protocols (Morpho Blue, Aave V3, Compound V3, and future protocols) to enable borrowing against tokenized stock collateral. Each protocol has its own oracle interface requirements:

- **Morpho Blue**: Expects `IOracle.price()` returning a `uint256` scaled to 1e36
- **Aave V3**: Expects Chainlink's `AggregatorV3Interface` with `latestAnswer()` and `latestRoundData()`
- **Compound V3 (Comet)**: Expects Chainlink's `AggregatorV3Interface` with 8 decimal precision

The underlying price source is **Pyth Network**, which provides NBBO pricing for equities.

**Key challenges:**

1. Different protocols expect different interfaces and scaling
2. Oracle addresses are often immutable once set in lending markets (especially Morpho)
3. Corporate actions (splits, dividends) require pausing price feeds temporarily
4. Upgrades to one layer shouldn't require upgrades to another

---

## 2. Goals

1. **True onchain modularity**: Oracle adapters and protocol adapters are separate deployments
2. **Industry standard interface**: Use Chainlink's `AggregatorV3Interface` as the contract boundary
3. **Swappable sources**: Protocol adapters can point to any oracle (Pyth today, Chainlink tomorrow)
4. **Independent upgrade paths**: Fix bugs in Pyth parsing without touching protocol adapters
5. **Beacon proxy pattern**: Both layers use beacon proxies per `st0x.deploy` patterns

### 2.1 Relationship to rain.pyth

| Aspect | rain.pyth | st0x.oracle |
|--------|-----------|-------------|
| Purpose | Rain interpreter word | DeFi protocol integration |
| Interface | Returns `Float` (Rain format) | Returns `int256` (8 decimals) |
| Lookup | Runtime symbol lookup | Per-token deployed proxy |
| Pattern | Direct deployment | BeaconSetDeployer pattern |
| Governance | None (stateless) | Admin controls (pause, setPriceId) |

**What we reuse from rain.pyth:**

- `LibPyth.getPriceFeedContract(block.chainid)` - derives Pyth contract address at runtime (audited code)
- Price feed ID constants for all supported equities

---

## 3. Architecture Overview

```
PROTOCOL ADAPTERS
(indirection layer - allows oracle swaps without protocol governance)

┌─────────────────┐  ┌────────────────────────────────────┐
│ MorphoAdapter   │  │ PassthroughAdapter                 │
│                 │  │ (multiple instances: Aave,         │
│ IOracle         │  │  Compound, future protocols)       │
│ (8→36 dec)      │  │ AggregatorV3 (passthrough)         │
└───────┬─────────┘  └───────────────┬────────────────────┘
        │                            │
        └────────────┬───────────────┘
                     ▼
           ┌─────────────────────────┐
           │  AggregatorV3Interface  │  ← industry standard
           └─────────────────────────┘
                     ▲
          ┌──────────┴───────────────┐
          │       implements         │
          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│ PythOracleAdapter   │    │ ChainlinkOracle     │
│                     │    │ Adapter (future)    │
│ Governance:         │    │                     │
│  - set priceId      │    │                     │
│  - set maxAge       │    │                     │
│  - pause/unpause    │    │                     │
└─────────────────────┘    └─────────────────────┘

ORACLE ADAPTERS
(canonical oracle per asset, all governance here)
```

**Why protocol adapters for ALL protocols (even Chainlink-compatible ones):**

Without protocol adapter:
- Aave/Compound points directly to `PythOracleAdapter`
- Pyth dies → Need Aave/Compound governance to update their oracle registry
- ST0x has no control over the switch

With protocol adapter:
- Aave/Compound points to `PassthroughProtocolAdapter`
- Pyth dies → ST0x calls `protocolAdapter.setOracle(chainlinkOracleAdapter)`
- Protocol is unaware, no governance action needed on their side

---

## 4. Protocol Adapter Types

| Protocol | Interface | Adapter Type |
|----------|-----------|-------------|
| Morpho Blue | `IOracle.price()` (36 dec) | `MorphoProtocolAdapter` • scales 8→36 |
| Aave V3 | `AggregatorV3Interface` (8 dec) | `PassthroughProtocolAdapter` instance |
| Compound V3 | `AggregatorV3Interface` (8 dec) | `PassthroughProtocolAdapter` instance |
| Future Chainlink-compatible | `AggregatorV3Interface` (8 dec) | `PassthroughProtocolAdapter` instance |

**Two adapter contracts (not three):**

- `MorphoProtocolAdapter` - scales 8→36 decimals
- `PassthroughProtocolAdapter` - used by Aave, Compound, any Chainlink-compatible protocol

Deploy multiple proxy *instances* from the same beacon for different protocols.

---

## 5. PythOracleAdapter Implementation

**Storage:**

```solidity
address public st0xToken;        // Set once, no setter
string internal _description;    // e.g., "AAPL / USD"
bytes32 public priceId;          // Pyth feed ID
uint256 public maxAge;           // Max acceptable price age
bool public paused;              // Emergency pause
```

Note: No `pyth` address storage - derived from `LibPyth.getPriceFeedContract(block.chainid)` at runtime.

**Implementation:**

```solidity
import {LibPyth} from "rain.pyth/src/lib/pyth/LibPyth.sol";

function latestAnswer() external view override returns (int256) {
    _validateNotPaused();

    // Get Pyth contract from LibPyth (audited code)
    IPyth pyth = LibPyth.getPriceFeedContract(block.chainid);

    // Fetch price - reverts if older than maxAge
    PythStructs.Price memory priceData = pyth.getPriceNoOlderThan(priceId, maxAge);

    // Scale to 8 decimals (Chainlink standard)
    int256 scaledPrice = _scaleToDecimals(priceData.price, priceData.expo, 8);

    return scaledPrice;
}
```

---

## 6. PassthroughProtocolAdapter Implementation

For protocols using `AggregatorV3Interface` (Aave V3, Compound V3, future Chainlink-compatible protocols):

```solidity
contract PassthroughProtocolAdapter is AggregatorV3Interface {
    AggregatorV3Interface public oracle;   // Reference to oracle adapter (updatable)

    function setOracle(AggregatorV3Interface newOracle) external onlyAdmin {
        oracle = newOracle;
    }

    function decimals() external view override returns (uint8) {
        return oracle.decimals();
    }

    function latestAnswer() external view override returns (int256) {
        return oracle.latestAnswer();
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return oracle.latestRoundData();
    }
}
```

**Usage:**

- Deploy one proxy instance for Aave (AAPL)
- Deploy another proxy instance for Compound (AAPL)
- Both share the same beacon and implementation
- Each instance has independent `oracle` reference

---

## 7. MorphoProtocolAdapter Implementation

Morpho Blue requires `IOracle.price()` returning 36-decimal scaled price:

```solidity
contract MorphoProtocolAdapter is IOracle {
    AggregatorV3Interface public oracle;   // Reference to oracle adapter (updatable)

    function setOracle(AggregatorV3Interface newOracle) external onlyAdmin {
        oracle = newOracle;
    }

    function price() external view override returns (uint256) {
        int256 answer = oracle.latestAnswer();
        require(answer > 0, "Invalid price");

        // Scale from 8 decimals to 36 decimals
        return uint256(answer) * 1e28;
    }
}
```

---

## 8. BeaconSetDeployer Pattern

Following `st0x.deploy` patterns:

**Oracle Adapter Layer:**

```solidity
contract PythOracleAdapterBeaconSetDeployer {
    IBeacon public immutable I_PYTH_ORACLE_ADAPTER_BEACON;

    constructor(config) {
        I_PYTH_ORACLE_ADAPTER_BEACON = new UpgradeableBeacon(
            config.initialPythOracleAdapterImplementation,
            config.initialOwner
        );
    }

    function newPythOracleAdapter(
        address st0xToken,
        bytes32 priceId,
        uint256 maxAge,
        string memory description
    ) external returns (PythOracleAdapter);
}
```

**Protocol Adapter Layer:**

```solidity
contract PassthroughProtocolAdapterBeaconSetDeployer {
    IBeacon public immutable I_PASSTHROUGH_PROTOCOL_ADAPTER_BEACON;

    function newPassthroughProtocolAdapter(
        AggregatorV3Interface oracle
    ) external returns (PassthroughProtocolAdapter);
}
```

---

## 9. Deployment Flow

**Initial deployment (once per chain):**

1. Deploy PythOracleAdapterV1 implementation
2. Deploy PythOracleAdapterBeaconSetDeployer (creates beacon internally)
3. Deploy MorphoProtocolAdapterV1 implementation
4. Deploy MorphoProtocolAdapterBeaconSetDeployer
5. Deploy PassthroughProtocolAdapterV1 implementation
6. Deploy PassthroughProtocolAdapterBeaconSetDeployer
7. Deploy OracleUnifiedDeployer

**For a new asset (e.g., AAPL/USD):**

```solidity
OracleUnifiedDeployer.newOracleAndProtocolAdapters(
    st0xToken,      // AAPL token address
    priceId,        // AAPL/USD feed ID (from LibPyth constants)
    60,             // maxAge in seconds
    "AAPL / USD"    // description
);
// Pyth address derived from LibPyth.getPriceFeedContract(block.chainid)
```

---

## 10. Repository Structure

```
st0x.oracle/
├── lib/
│   ├── rain.pyth/                              # For LibPyth
│   └── pyth-sdk-solidity/                      # Pyth structs
├── src/
│   ├── concrete/
│   │   ├── oracle/
│   │   │   └── PythOracleAdapter.sol
│   │   ├── protocol/
│   │   │   ├── MorphoProtocolAdapter.sol       # Scales 8→36
│   │   │   └── PassthroughProtocolAdapter.sol  # For Aave, Compound
│   │   └── deploy/
│   │       ├── PythOracleAdapterBeaconSetDeployer.sol
│   │       ├── MorphoProtocolAdapterBeaconSetDeployer.sol
│   │       ├── PassthroughProtocolAdapterBeaconSetDeployer.sol
│   │       └── OracleUnifiedDeployer.sol
│   └── lib/
│       └── LibProdDeploy.sol
└── test/
```

---

## 11. LibPyth Usage

**Runtime (in PythOracleAdapter):**

```solidity
// No pyth address stored - derived at runtime from audited code
IPyth pyth = LibPyth.getPriceFeedContract(block.chainid);
```

**Constants (for deployment):**

```solidity
// From LibPyth.sol - already mapped
bytes32 constant PRICE_FEED_ID_EQUITY_US_AAPL_USD = 0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688;
bytes32 constant PRICE_FEED_ID_EQUITY_US_TSLA_USD = 0x16dad506d7db8da01c87581c87ca897a012a153557d4d578c3b9c9e1bc0632f1;
bytes32 constant PRICE_FEED_ID_EQUITY_US_NVDA_USD = 0xb1073854ed24cbc755dc527418f52b7d271f6cc967bbf8d8129112b18860a593;
// ... GOOG, AMZN, MSFT, META, GME, MSTR, COIN, etc.

// Chain ID → Pyth contract
IPyth constant PRICE_FEED_CONTRACT_BASE = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);
```

---

## 12. Governance

All admin roles held by founder multisig:

- **Beacon Owner**: Can upgrade implementation
- **Oracle Admin**: Can update priceId, maxAge, pause/unpause
- **Protocol Adapter Admin**: Can update oracle reference

No separation of roles.

---

## 13. Upgrade & Migration Scenarios

| Scenario | Action | Unchanged |
|----------|--------|-----------|
| Bug in Pyth price parsing | Upgrade PythOracleBeacon implementation | All protocol adapters |
| Bug in Morpho scaling | Upgrade MorphoAdapterBeacon implementation | All oracle adapters |
| Add Aave support | Deploy PassthroughAdapter proxy pointing to existing oracle | Everything else |
| Pyth dies, switch to Chainlink | Deploy ChainlinkOracleAdapter, update protocol adapters' oracle references | Old PythOracle stays deployed |
| Corporate action (AAPL split) | Pause PythOracleAdapter, execute split, unpause | Protocol adapters unaware |

---

## 14. Security Considerations

1. **Negative prices**: Pyth prices can theoretically be negative; handle appropriately (revert)
2. **Confidence intervals**: Pyth provides confidence data; consider rejecting wide confidence
3. **Overflow**: Ensure scaling math cannot overflow
4. **Corporate actions**: Pause mechanism exists to prevent trading during splits/dividends

---

## 15. References

- **rain.pyth**: https://github.com/rainlanguage/rain.pyth
- **st0x.deploy**: https://github.com/S01-Issuer/st0x.deploy
- **Pyth Network**: https://docs.pyth.network/
- **Chainlink AggregatorV3Interface**: https://github.com/smartcontractkit/chainlink
