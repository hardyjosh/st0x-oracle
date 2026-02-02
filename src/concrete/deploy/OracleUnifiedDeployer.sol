// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PythOracleAdapterBeaconSetDeployer} from "src/concrete/deploy/PythOracleAdapterBeaconSetDeployer.sol";
import {PassthroughProtocolAdapterBeaconSetDeployer} from
    "src/concrete/deploy/PassthroughProtocolAdapterBeaconSetDeployer.sol";
import {MorphoProtocolAdapterBeaconSetDeployer} from "src/concrete/deploy/MorphoProtocolAdapterBeaconSetDeployer.sol";
import {PythOracleAdapter, PythOracleAdapterConfig} from "src/concrete/oracle/PythOracleAdapter.sol";
import {PassthroughProtocolAdapter} from "src/concrete/protocol/PassthroughProtocolAdapter.sol";
import {MorphoProtocolAdapter} from "src/concrete/protocol/MorphoProtocolAdapter.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";
import {LibProdDeploy} from "src/lib/LibProdDeploy.sol";

/// @title OracleUnifiedDeployer
/// @notice Atomically deploys a PythOracleAdapter and all protocol adapters
/// (Morpho, Passthrough for Aave/Compound) for a new asset. The beacon set
/// deployer addresses are hardcoded to simplify and harden deployment by
/// providing an audit trail in git of any address modifications.
contract OracleUnifiedDeployer {
    /// Emitted when a new oracle and protocol adapter set is deployed.
    event Deployment(
        address sender, address pythOracleAdapter, address morphoProtocolAdapter, address passthroughProtocolAdapter
    );

    /// @notice Deploy oracle + all protocol adapters for a new asset.
    /// @param st0xToken The st0x token address.
    /// @param priceId The Pyth price feed ID.
    /// @param maxAge Maximum acceptable price age in seconds.
    function newOracleAndProtocolAdapters(address st0xToken, bytes32 priceId, uint256 maxAge) external {
        // 1. Deploy oracle adapter
        PythOracleAdapter oracleAdapter = PythOracleAdapterBeaconSetDeployer(
            LibProdDeploy.PYTH_ORACLE_ADAPTER_BEACON_SET_DEPLOYER
        ).newPythOracleAdapter(
            PythOracleAdapterConfig({st0xToken: st0xToken, priceId: priceId, maxAge: maxAge, admin: msg.sender})
        );

        AggregatorV3Interface oracleRef = AggregatorV3Interface(address(oracleAdapter));

        // 2. Deploy Morpho protocol adapter
        MorphoProtocolAdapter morphoAdapter = MorphoProtocolAdapterBeaconSetDeployer(
            LibProdDeploy.MORPHO_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER
        ).newMorphoProtocolAdapter(oracleRef, msg.sender);

        // 3. Deploy passthrough protocol adapter (for Aave/Compound)
        PassthroughProtocolAdapter passthroughAdapter = PassthroughProtocolAdapterBeaconSetDeployer(
            LibProdDeploy.PASSTHROUGH_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER
        ).newPassthroughProtocolAdapter(oracleRef, msg.sender);

        emit Deployment(msg.sender, address(oracleAdapter), address(morphoAdapter), address(passthroughAdapter));
    }
}
