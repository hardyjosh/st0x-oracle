// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IPyth} from "pyth-sdk/IPyth.sol";
import {PythStructs} from "pyth-sdk/PythStructs.sol";
import {LibPyth} from "rain.pyth/lib/pyth/LibPyth.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @dev Error raised when the oracle is paused.
error OraclePaused();

/// @dev Error raised when the scaled price is not positive.
error NonPositivePrice();

/// @dev Error raised when a zero address is provided for the st0x token.
error ZeroSt0xToken();

/// @dev Error raised when a zero price ID is provided.
error ZeroPriceId();

/// @dev Error raised when a zero max age is provided.
error ZeroMaxAge();

/// @dev Error raised when the caller is not the admin.
error OnlyAdmin();

/// @title PythOracleAdapter
/// @notice Oracle adapter that fetches prices from Pyth Network and exposes
/// them via Chainlink's AggregatorV3Interface. This is the canonical oracle
/// per asset - all governance (pause, setPriceId, setMaxAge) lives here.
/// Pyth contract address is NOT stored - derived at runtime from
/// LibPyth.getPriceFeedContract(block.chainid).
contract PythOracleAdapter is Initializable {
    /// @dev The st0x token this oracle is for. Set once during initialization.
    address public st0xToken;
    /// @dev Human-readable description, e.g., "AAPL / USD".
    string internal _description;
    /// @dev The Pyth price feed ID for this asset.
    bytes32 public priceId;
    /// @dev Maximum acceptable price age in seconds.
    uint256 public maxAge;
    /// @dev Emergency pause flag.
    bool public paused;
    /// @dev Admin address for governance actions.
    address public admin;

    /// @dev Emitted when the oracle is initialized.
    event Initialized(address indexed sender, address indexed st0xToken, bytes32 priceId, uint256 maxAge, string description);
    /// @dev Emitted when the price ID is updated.
    event PriceIdSet(bytes32 oldPriceId, bytes32 newPriceId);
    /// @dev Emitted when the max age is updated.
    event MaxAgeSet(uint256 oldMaxAge, uint256 newMaxAge);
    /// @dev Emitted when the pause state changes.
    event PauseSet(bool isPaused);

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the oracle adapter.
    /// @param st0xToken_ The st0x token address this oracle serves.
    /// @param priceId_ The Pyth price feed ID.
    /// @param maxAge_ Maximum acceptable price age in seconds.
    /// @param description_ Human-readable description.
    /// @param admin_ The admin address for governance.
    function initialize(
        address st0xToken_,
        bytes32 priceId_,
        uint256 maxAge_,
        string memory description_,
        address admin_
    ) external initializer {
        if (st0xToken_ == address(0)) revert ZeroSt0xToken();
        if (priceId_ == bytes32(0)) revert ZeroPriceId();
        if (maxAge_ == 0) revert ZeroMaxAge();

        st0xToken = st0xToken_;
        priceId = priceId_;
        maxAge = maxAge_;
        _description = description_;
        admin = admin_;

        emit Initialized(msg.sender, st0xToken_, priceId_, maxAge_, description_);
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    /// @notice Returns the description of this oracle feed.
    function description() external view returns (string memory) {
        return _description;
    }

    /// @notice Returns the number of decimals (Chainlink standard: 8).
    function decimals() external pure returns (uint8) {
        return 8;
    }

    /// @notice Returns the latest price scaled to 8 decimals.
    /// @dev Reverts if paused, if the price is stale, or if the price is not
    /// positive.
    function latestAnswer() external view returns (int256) {
        _validateNotPaused();

        IPyth pyth = LibPyth.getPriceFeedContract(block.chainid);
        PythStructs.Price memory priceData = pyth.getPriceNoOlderThan(priceId, maxAge);

        int256 scaledPrice = _scaleToDecimals(priceData.price, priceData.expo, 8);
        if (scaledPrice <= 0) revert NonPositivePrice();

        return scaledPrice;
    }

    /// @notice Returns the latest round data in Chainlink AggregatorV3Interface
    /// format.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        _validateNotPaused();

        IPyth pyth = LibPyth.getPriceFeedContract(block.chainid);
        PythStructs.Price memory priceData = pyth.getPriceNoOlderThan(priceId, maxAge);

        int256 scaledPrice = _scaleToDecimals(priceData.price, priceData.expo, 8);
        if (scaledPrice <= 0) revert NonPositivePrice();

        return (
            1, // roundId - Pyth doesn't have rounds
            scaledPrice,
            uint256(uint64(priceData.publishTime)),
            uint256(uint64(priceData.publishTime)),
            1 // answeredInRound
        );
    }

    /// @notice Set the Pyth price feed ID. Admin only.
    function setPriceId(bytes32 newPriceId) external onlyAdmin {
        if (newPriceId == bytes32(0)) revert ZeroPriceId();
        emit PriceIdSet(priceId, newPriceId);
        priceId = newPriceId;
    }

    /// @notice Set the maximum acceptable price age. Admin only.
    function setMaxAge(uint256 newMaxAge) external onlyAdmin {
        if (newMaxAge == 0) revert ZeroMaxAge();
        emit MaxAgeSet(maxAge, newMaxAge);
        maxAge = newMaxAge;
    }

    /// @notice Pause or unpause the oracle. Admin only.
    function setPaused(bool isPaused) external onlyAdmin {
        paused = isPaused;
        emit PauseSet(isPaused);
    }

    /// @dev Reverts if the oracle is paused.
    function _validateNotPaused() internal view {
        if (paused) revert OraclePaused();
    }

    /// @dev Scale a Pyth price (with exponent) to the target number of
    /// decimals.
    /// @param price The raw Pyth price.
    /// @param expo The Pyth exponent (negative for decimals).
    /// @param targetDecimals The target number of decimals.
    /// @return The scaled price as int256.
    function _scaleToDecimals(int64 price, int32 expo, uint8 targetDecimals) internal pure returns (int256) {
        int256 result = int256(price);
        // expo is typically negative, e.g., -8 means 8 decimals
        int32 currentDecimals = -expo;
        int32 target = int32(uint32(targetDecimals));

        if (currentDecimals > target) {
            // Reduce decimals
            result = result / int256(10 ** uint256(uint32(currentDecimals - target)));
        } else if (currentDecimals < target) {
            // Increase decimals
            result = result * int256(10 ** uint256(uint32(target - currentDecimals)));
        }
        return result;
    }
}
