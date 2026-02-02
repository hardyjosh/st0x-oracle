// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {
    MorphoProtocolAdapter,
    MorphoProtocolAdapterConfig,
    OnlyAdmin,
    ZeroOracle,
    NonPositivePrice
} from "src/concrete/protocol/MorphoProtocolAdapter.sol";
import {
    MorphoProtocolAdapterBeaconSetDeployer,
    MorphoProtocolAdapterBeaconSetDeployerConfig
} from "src/concrete/deploy/MorphoProtocolAdapterBeaconSetDeployer.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";

contract MorphoProtocolAdapterTest is Test {
    MorphoProtocolAdapter internal immutable I_IMPLEMENTATION;
    MorphoProtocolAdapterBeaconSetDeployer internal immutable I_DEPLOYER;

    constructor() {
        I_IMPLEMENTATION = new MorphoProtocolAdapter();
        I_DEPLOYER = new MorphoProtocolAdapterBeaconSetDeployer(
            MorphoProtocolAdapterBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialMorphoProtocolAdapterImplementation: address(I_IMPLEMENTATION)
            })
        );
    }

    /// Test that initialization with zero oracle reverts.
    function testInitializeZeroOracle(address admin) external {
        vm.expectRevert(abi.encodeWithSelector(ZeroOracle.selector));
        I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(address(0)), admin);
    }

    /// Test successful initialization.
    function testInitializeSuccess(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));

        MorphoProtocolAdapter adapter = I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        assertEq(address(adapter.oracle()), oracleAddr);
        assertEq(adapter.admin(), admin);
    }

    /// Test that initialization emits event.
    function testInitializeEvent(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));

        vm.recordLogs();
        I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool eventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("MorphoProtocolAdapterInitialized(address,(address,address))")) {
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound, "MorphoProtocolAdapterInitialized event not found");
    }

    /// Test setOracle by admin.
    function testSetOracle(address oracleAddr, address newOracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(newOracleAddr != address(0));
        vm.assume(admin != address(0));

        MorphoProtocolAdapter adapter = I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.expectEmit();
        emit MorphoProtocolAdapter.OracleSet(oracleAddr, newOracleAddr);
        vm.prank(admin);
        adapter.setOracle(AggregatorV3Interface(newOracleAddr));

        assertEq(address(adapter.oracle()), newOracleAddr);
    }

    /// Test setOracle reverts for non-admin.
    function testSetOracleOnlyAdmin(address oracleAddr, address admin, address nonAdmin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(admin != address(0));
        vm.assume(nonAdmin != admin);

        MorphoProtocolAdapter adapter = I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(OnlyAdmin.selector));
        adapter.setOracle(AggregatorV3Interface(oracleAddr));
    }

    /// Test setOracle with zero address reverts.
    function testSetOracleZeroAddress(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(admin != address(0));

        MorphoProtocolAdapter adapter = I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ZeroOracle.selector));
        adapter.setOracle(AggregatorV3Interface(address(0)));
    }

    /// Test price() scales 8 decimals to 36 decimals correctly.
    function testPriceScaling(address admin) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));

        // Mock a price of 100.00000000 (100 USD at 8 decimals)
        int256 mockPrice = 100e8;
        vm.mockCall(
            mockOracle, abi.encodeWithSelector(AggregatorV3Interface.latestAnswer.selector), abi.encode(mockPrice)
        );

        MorphoProtocolAdapter adapter =
            I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        uint256 morphoPrice = adapter.price();
        // 100e8 * 1e28 = 100e36
        assertEq(morphoPrice, 100e36);
    }

    /// Test price() with various values.
    function testPriceScalingFuzz(address admin, int256 mockPrice) external {
        vm.assume(admin != address(0));
        // Price must be positive and not overflow when multiplied by 1e28.
        mockPrice = bound(mockPrice, 1, int256(type(uint256).max / 1e28));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle, abi.encodeWithSelector(AggregatorV3Interface.latestAnswer.selector), abi.encode(mockPrice)
        );

        MorphoProtocolAdapter adapter =
            I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        uint256 morphoPrice = adapter.price();
        assertEq(morphoPrice, uint256(mockPrice) * 1e28);
    }

    /// Test price() reverts on zero price.
    function testPriceRevertsOnZero(address admin) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle, abi.encodeWithSelector(AggregatorV3Interface.latestAnswer.selector), abi.encode(int256(0))
        );

        MorphoProtocolAdapter adapter =
            I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector));
        adapter.price();
    }

    /// Test price() reverts on negative price.
    function testPriceRevertsOnNegative(address admin, int256 negativePrice) external {
        vm.assume(admin != address(0));
        negativePrice = bound(negativePrice, type(int256).min, -1);

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestAnswer.selector),
            abi.encode(negativePrice)
        );

        MorphoProtocolAdapter adapter =
            I_DEPLOYER.newMorphoProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector));
        adapter.price();
    }
}
