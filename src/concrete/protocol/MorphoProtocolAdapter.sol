// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "src/concrete/protocol/PassthroughProtocolAdapter.sol";

/// @dev Error raised when the caller is not the admin.
error OnlyAdmin();

/// @dev Error raised when a zero address is provided for the oracle.
error ZeroOracle();

/// @dev Error raised when the price is not positive.
error NonPositivePrice();

/// @dev Morpho Blue's IOracle interface.
interface IOracle {
    function price() external view returns (uint256);
}

/// @title MorphoProtocolAdapter
/// @notice Protocol adapter for Morpho Blue. Implements Morpho's IOracle
/// interface by reading from an underlying AggregatorV3Interface oracle and
/// scaling from 8 decimals to 36 decimals.
/// The oracle reference is updatable by the admin, allowing oracle swaps
/// without Morpho governance (oracle addresses are immutable in Morpho markets).
contract MorphoProtocolAdapter is IOracle, Initializable {
    /// @dev The underlying oracle adapter implementing AggregatorV3Interface.
    AggregatorV3Interface public oracle;
    /// @dev Admin address for governance actions.
    address public admin;

    /// @dev Emitted when the oracle reference is updated.
    event OracleSet(address indexed oldOracle, address indexed newOracle);

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the protocol adapter.
    /// @param oracle_ The initial oracle adapter address.
    /// @param admin_ The admin address.
    function initialize(AggregatorV3Interface oracle_, address admin_) external initializer {
        if (address(oracle_) == address(0)) revert ZeroOracle();
        oracle = oracle_;
        admin = admin_;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    /// @notice Update the oracle reference. Admin only.
    function setOracle(AggregatorV3Interface newOracle) external onlyAdmin {
        if (address(newOracle) == address(0)) revert ZeroOracle();
        emit OracleSet(address(oracle), address(newOracle));
        oracle = newOracle;
    }

    /// @notice Returns the price scaled to 36 decimals as required by Morpho
    /// Blue.
    /// @return The price as uint256 scaled to 1e36.
    function price() external view override returns (uint256) {
        int256 answer = oracle.latestAnswer();
        if (answer <= 0) revert NonPositivePrice();

        // Scale from 8 decimals to 36 decimals
        return uint256(answer) * 1e28;
    }
}
