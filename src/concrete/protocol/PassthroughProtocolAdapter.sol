// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICLONEABLE_V2_SUCCESS, ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";

/// @dev Error raised when the caller is not the admin.
error OnlyAdmin();

/// @dev Error raised when a zero address is provided for the oracle.
error ZeroOracle();

/// @title PassthroughProtocolAdapterConfig
/// @notice Configuration for PassthroughProtocolAdapter initialization.
/// @param oracle The initial oracle adapter address.
/// @param admin The admin address.
struct PassthroughProtocolAdapterConfig {
    AggregatorV3Interface oracle;
    address admin;
}

/// @title PassthroughProtocolAdapter
/// @notice Protocol adapter for Aave V3, Compound V3, and any future
/// Chainlink-compatible protocol. Passes through all AggregatorV3Interface
/// calls to the underlying oracle adapter. The oracle reference is updatable
/// by the admin, allowing oracle swaps without protocol governance.
/// Deploy multiple proxy instances from the same beacon for different protocols.
contract PassthroughProtocolAdapter is ICloneableV2, Initializable {
    /// @dev The underlying oracle adapter implementing AggregatorV3Interface.
    AggregatorV3Interface public oracle;
    /// @dev Admin address for governance actions.
    address public admin;

    /// @dev Emitted when the adapter is initialized.
    event PassthroughProtocolAdapterInitialized(address indexed sender, PassthroughProtocolAdapterConfig config);
    /// @dev Emitted when the oracle reference is updated.
    event OracleSet(address indexed oldOracle, address indexed newOracle);

    constructor() {
        _disableInitializers();
    }

    /// As per ICloneableV2, this overload MUST always revert. Documents the
    /// signature of the initialize function.
    /// @param config The initialization configuration.
    function initialize(PassthroughProtocolAdapterConfig memory config) external pure returns (bytes32) {
        (config);
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        PassthroughProtocolAdapterConfig memory config = abi.decode(data, (PassthroughProtocolAdapterConfig));

        if (address(config.oracle) == address(0)) revert ZeroOracle();

        oracle = config.oracle;
        admin = config.admin;

        emit PassthroughProtocolAdapterInitialized(msg.sender, config);

        return ICLONEABLE_V2_SUCCESS;
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
