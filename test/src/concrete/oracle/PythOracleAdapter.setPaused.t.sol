// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PythOracleAdapterTest} from "test/abstract/PythOracleAdapterTest.sol";
import {PythOracleAdapter, OraclePaused, OnlyAdmin} from "src/concrete/oracle/PythOracleAdapter.sol";
import {AggregatorV3Interface} from "src/interface/IAggregatorV3.sol";

contract PythOracleAdapterSetPausedTest is PythOracleAdapterTest {
    /// Test that setPaused works for admin.
    function testSetPaused(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        assertEq(oracle.paused(), false);

        vm.prank(admin);
        oracle.setPaused(true);
        assertEq(oracle.paused(), true);

        vm.prank(admin);
        oracle.setPaused(false);
        assertEq(oracle.paused(), false);
    }

    /// Test that setPaused reverts for non-admin.
    function testSetPausedOnlyAdmin(
        address st0xToken,
        bytes32 priceId,
        uint256 maxAge,
        address admin,
        address nonAdmin
    ) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));
        vm.assume(nonAdmin != admin);

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(OnlyAdmin.selector));
        oracle.setPaused(true);
    }

    /// Test that latestAnswer reverts when paused.
    function testLatestAnswerWhenPaused(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        vm.prank(admin);
        oracle.setPaused(true);

        vm.expectRevert(abi.encodeWithSelector(OraclePaused.selector));
        oracle.latestAnswer();
    }

    /// Test that latestRoundData reverts when paused.
    function testLatestRoundDataWhenPaused(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        vm.prank(admin);
        oracle.setPaused(true);

        vm.expectRevert(abi.encodeWithSelector(OraclePaused.selector));
        oracle.latestRoundData();
    }

    /// Test that PauseSet event is emitted.
    function testPauseSetEvent(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        vm.expectEmit();
        emit PythOracleAdapter.PauseSet(true);
        vm.prank(admin);
        oracle.setPaused(true);

        vm.expectEmit();
        emit PythOracleAdapter.PauseSet(false);
        vm.prank(admin);
        oracle.setPaused(false);
    }
}
