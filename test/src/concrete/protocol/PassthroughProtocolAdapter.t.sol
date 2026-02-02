// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {
    PassthroughProtocolAdapter,
    PassthroughProtocolAdapterConfig,
    OnlyAdmin,
    ZeroOracle
} from "src/concrete/protocol/PassthroughProtocolAdapter.sol";
import {
    PassthroughProtocolAdapterBeaconSetDeployer,
    PassthroughProtocolAdapterBeaconSetDeployerConfig
} from "src/concrete/deploy/PassthroughProtocolAdapterBeaconSetDeployer.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";

contract PassthroughProtocolAdapterTest is Test {
    PassthroughProtocolAdapter internal immutable I_IMPLEMENTATION;
    PassthroughProtocolAdapterBeaconSetDeployer internal immutable I_DEPLOYER;

    constructor() {
        I_IMPLEMENTATION = new PassthroughProtocolAdapter();
        I_DEPLOYER = new PassthroughProtocolAdapterBeaconSetDeployer(
            PassthroughProtocolAdapterBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialPassthroughProtocolAdapterImplementation: address(I_IMPLEMENTATION)
            })
        );
    }

    /// Test that initialization with zero oracle reverts.
    function testInitializeZeroOracle(address admin) external {
        vm.expectRevert(abi.encodeWithSelector(ZeroOracle.selector));
        I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(address(0)), admin);
    }

    /// Test successful initialization.
    function testInitializeSuccess(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        assertEq(address(adapter.oracle()), oracleAddr);
        assertEq(adapter.admin(), admin);
    }

    /// Test that initialization emits event.
    function testInitializeEvent(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));

        vm.recordLogs();
        I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool eventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256("PassthroughProtocolAdapterInitialized(address,(address,address))")
            ) {
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound, "PassthroughProtocolAdapterInitialized event not found");
    }

    /// Test setOracle by admin.
    function testSetOracle(address oracleAddr, address newOracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(newOracleAddr != address(0));
        vm.assume(admin != address(0));

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.expectEmit();
        emit PassthroughProtocolAdapter.OracleSet(oracleAddr, newOracleAddr);
        vm.prank(admin);
        adapter.setOracle(AggregatorV3Interface(newOracleAddr));

        assertEq(address(adapter.oracle()), newOracleAddr);
    }

    /// Test setOracle reverts for non-admin.
    function testSetOracleOnlyAdmin(address oracleAddr, address admin, address nonAdmin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(admin != address(0));
        vm.assume(nonAdmin != admin);

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(OnlyAdmin.selector));
        adapter.setOracle(AggregatorV3Interface(oracleAddr));
    }

    /// Test setOracle with zero address reverts.
    function testSetOracleZeroAddress(address oracleAddr, address admin) external {
        vm.assume(oracleAddr != address(0));
        vm.assume(admin != address(0));

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(oracleAddr), admin);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ZeroOracle.selector));
        adapter.setOracle(AggregatorV3Interface(address(0)));
    }

    /// Test passthrough of decimals.
    function testPassthroughDecimals(address admin) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(mockOracle, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(uint8(8)));

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        assertEq(adapter.decimals(), 8);
    }

    /// Test passthrough of latestAnswer.
    function testPassthroughLatestAnswer(address admin, int256 mockPrice) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle, abi.encodeWithSelector(AggregatorV3Interface.latestAnswer.selector), abi.encode(mockPrice)
        );

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        assertEq(adapter.latestAnswer(), mockPrice);
    }

    /// Test passthrough of latestRoundData.
    function testPassthroughLatestRoundData(address admin) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), int256(10000e8), uint256(1000), uint256(1000), uint80(1))
        );

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            adapter.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, 10000e8);
        assertEq(startedAt, 1000);
        assertEq(updatedAt, 1000);
        assertEq(answeredInRound, 1);
    }

    /// Test passthrough of description.
    function testPassthroughDescription(address admin) external {
        vm.assume(admin != address(0));

        address mockOracle = address(uint160(uint256(keccak256("mock.oracle"))));
        vm.mockCall(
            mockOracle, abi.encodeWithSelector(AggregatorV3Interface.description.selector), abi.encode("")
        );

        PassthroughProtocolAdapter adapter =
            I_DEPLOYER.newPassthroughProtocolAdapter(AggregatorV3Interface(mockOracle), admin);

        assertEq(adapter.description(), "");
    }
}
