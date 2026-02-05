// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OracleUnifiedDeployer} from "src/concrete/deploy/OracleUnifiedDeployer.sol";
import {LibProdDeploy} from "src/lib/LibProdDeploy.sol";
import {PythOracleAdapterBeaconSetDeployer} from "src/concrete/deploy/PythOracleAdapterBeaconSetDeployer.sol";
import {PassthroughProtocolAdapterBeaconSetDeployer} from
    "src/concrete/deploy/PassthroughProtocolAdapterBeaconSetDeployer.sol";
import {MorphoProtocolAdapterBeaconSetDeployer} from "src/concrete/deploy/MorphoProtocolAdapterBeaconSetDeployer.sol";
import {PythOracleAdapterConfig} from "src/concrete/oracle/PythOracleAdapter.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";

contract OracleUnifiedDeployerTest is Test {
    function testOracleUnifiedDeployer(
        address vault,
        bytes32 priceId,
        uint256 maxAge,
        address oracleAdapter,
        address morphoAdapter,
        address passthroughAdapter
    ) external {
        vm.assume(oracleAdapter.code.length == 0);
        vm.assume(morphoAdapter.code.length == 0);
        vm.assume(passthroughAdapter.code.length == 0);

        OracleUnifiedDeployer unifiedDeployer = new OracleUnifiedDeployer();

        // Mock the PythOracleAdapterBeaconSetDeployer at the prod address.
        vm.etch(LibProdDeploy.PYTH_ORACLE_ADAPTER_BEACON_SET_DEPLOYER, vm.getCode("PythOracleAdapterBeaconSetDeployer"));
        vm.mockCall(
            LibProdDeploy.PYTH_ORACLE_ADAPTER_BEACON_SET_DEPLOYER,
            abi.encodeWithSelector(
                PythOracleAdapterBeaconSetDeployer.newPythOracleAdapter.selector,
                PythOracleAdapterConfig({vault: vault, priceId: priceId, maxAge: maxAge, admin: address(this)})
            ),
            abi.encode(oracleAdapter)
        );

        // Mock the MorphoProtocolAdapterBeaconSetDeployer at the prod address.
        vm.etch(
            LibProdDeploy.MORPHO_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER,
            vm.getCode("MorphoProtocolAdapterBeaconSetDeployer")
        );
        vm.mockCall(
            LibProdDeploy.MORPHO_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER,
            abi.encodeWithSelector(
                MorphoProtocolAdapterBeaconSetDeployer.newMorphoProtocolAdapter.selector,
                AggregatorV3Interface(oracleAdapter),
                address(this)
            ),
            abi.encode(morphoAdapter)
        );

        // Mock the PassthroughProtocolAdapterBeaconSetDeployer at the prod address.
        vm.etch(
            LibProdDeploy.PASSTHROUGH_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER,
            vm.getCode("PassthroughProtocolAdapterBeaconSetDeployer")
        );
        vm.mockCall(
            LibProdDeploy.PASSTHROUGH_PROTOCOL_ADAPTER_BEACON_SET_DEPLOYER,
            abi.encodeWithSelector(
                PassthroughProtocolAdapterBeaconSetDeployer.newPassthroughProtocolAdapter.selector,
                AggregatorV3Interface(oracleAdapter),
                address(this)
            ),
            abi.encode(passthroughAdapter)
        );

        vm.expectEmit();
        emit OracleUnifiedDeployer.Deployment(address(this), oracleAdapter, morphoAdapter, passthroughAdapter);
        unifiedDeployer.newOracleAndProtocolAdapters(vault, priceId, maxAge);
    }
}
