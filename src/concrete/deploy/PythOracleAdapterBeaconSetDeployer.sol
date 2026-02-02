// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {PythOracleAdapter} from "src/concrete/oracle/PythOracleAdapter.sol";

/// @dev Error raised when a zero address is provided for the implementation.
error ZeroImplementation();

/// @dev Error raised when a zero address is provided for the initial beacon
/// owner.
error ZeroBeaconOwner();

/// @dev Error raised when a zero address is provided for the st0x token.
error ZeroSt0xToken();

/// @dev Error raised when a zero price ID is provided.
error ZeroPriceId();

/// @dev Error raised when a zero max age is provided.
error ZeroMaxAge();

/// @title PythOracleAdapterBeaconSetDeployerConfig
/// @notice Configuration for the PythOracleAdapterBeaconSetDeployer
/// construction.
/// @param initialOwner The initial owner of the beacon.
/// @param initialPythOracleAdapterImplementation The initial implementation.
struct PythOracleAdapterBeaconSetDeployerConfig {
    address initialOwner;
    address initialPythOracleAdapterImplementation;
}

/// @title PythOracleAdapterBeaconSetDeployer
/// @notice Deploys and manages a beacon set for PythOracleAdapter contracts.
/// Follows the st0x.deploy BeaconSetDeployer pattern.
contract PythOracleAdapterBeaconSetDeployer {
    /// Emitted when a new PythOracleAdapter is deployed.
    event Deployment(address sender, address pythOracleAdapter);

    /// The beacon for the PythOracleAdapter implementation contracts.
    IBeacon public immutable I_PYTH_ORACLE_ADAPTER_BEACON;

    constructor(PythOracleAdapterBeaconSetDeployerConfig memory config) {
        if (config.initialPythOracleAdapterImplementation == address(0)) {
            revert ZeroImplementation();
        }
        if (config.initialOwner == address(0)) {
            revert ZeroBeaconOwner();
        }

        I_PYTH_ORACLE_ADAPTER_BEACON =
            new UpgradeableBeacon(config.initialPythOracleAdapterImplementation, config.initialOwner);
    }

    /// @notice Deploys and initializes a new PythOracleAdapter proxy.
    /// @param st0xToken The st0x token address.
    /// @param priceId The Pyth price feed ID.
    /// @param maxAge Maximum acceptable price age in seconds.
    /// @param description_ Human-readable description.
    /// @param admin The admin address for governance.
    /// @return adapter The deployed PythOracleAdapter proxy.
    function newPythOracleAdapter(
        address st0xToken,
        bytes32 priceId,
        uint256 maxAge,
        string memory description_,
        address admin
    ) external returns (PythOracleAdapter) {
        if (st0xToken == address(0)) revert ZeroSt0xToken();
        if (priceId == bytes32(0)) revert ZeroPriceId();
        if (maxAge == 0) revert ZeroMaxAge();

        PythOracleAdapter adapter =
            PythOracleAdapter(address(new BeaconProxy(address(I_PYTH_ORACLE_ADAPTER_BEACON), "")));

        adapter.initialize(st0xToken, priceId, maxAge, description_, admin);

        emit Deployment(msg.sender, address(adapter));

        return adapter;
    }
}
