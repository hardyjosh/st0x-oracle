// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @dev Error raised when the caller is not the admin.
error OnlyAdmin();

/// @dev Error raised when a zero address is provided for the oracle.
error ZeroOracle();

/// @dev Interface matching Chainlink's AggregatorV3Interface.
/// We define it here to avoid pulling in Chainlink as a dependency.
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function latestAnswer() external view returns (int256);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title PassthroughProtocolAdapter
/// @notice Protocol adapter for Aave V3, Compound V3, and any future
/// Chainlink-compatible protocol. Passes through all AggregatorV3Interface
/// calls to the underlying oracle adapter. The oracle reference is updatable
/// by the admin, allowing oracle swaps without protocol governance.
/// Deploy multiple proxy instances from the same beacon for different protocols.
contract PassthroughProtocolAdapter is Initializable {
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

    /// @notice Returns the number of decimals from the underlying oracle.
    function decimals() external view returns (uint8) {
        return oracle.decimals();
    }

    /// @notice Returns the description from the underlying oracle.
    function description() external view returns (string memory) {
        return oracle.description();
    }

    /// @notice Returns the latest answer from the underlying oracle.
    function latestAnswer() external view returns (int256) {
        return oracle.latestAnswer();
    }

    /// @notice Returns the latest round data from the underlying oracle.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return oracle.latestRoundData();
    }
}
