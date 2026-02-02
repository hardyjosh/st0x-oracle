// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PythOracleAdapterTest} from "test/abstract/PythOracleAdapterTest.sol";
import {
    PythOracleAdapter,
    PythOracleAdapterConfig,
    ZeroSt0xToken,
    ZeroPriceId,
    ZeroMaxAge,
    ZeroAdmin
} from "src/concrete/oracle/PythOracleAdapter.sol";
import {Vm} from "forge-std/Test.sol";

contract PythOracleAdapterInitializeTest is PythOracleAdapterTest {
    /// Test that zero st0x token address reverts.
    function testInitializeZeroSt0xToken(bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroSt0xToken.selector));
        I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({st0xToken: address(0), priceId: priceId, maxAge: maxAge, admin: admin})
        );
    }

    /// Test that zero price ID reverts.
    function testInitializeZeroPriceId(address st0xToken, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroPriceId.selector));
        I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({st0xToken: st0xToken, priceId: bytes32(0), maxAge: maxAge, admin: admin})
        );
    }

    /// Test that zero max age reverts.
    function testInitializeZeroMaxAge(address st0xToken, bytes32 priceId, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(admin != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroMaxAge.selector));
        I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({st0xToken: st0xToken, priceId: priceId, maxAge: 0, admin: admin})
        );
    }

    /// Test that zero admin address reverts.
    function testInitializeZeroAdmin(address st0xToken, bytes32 priceId, uint256 maxAge) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroAdmin.selector));
        I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({st0xToken: st0xToken, priceId: priceId, maxAge: maxAge, admin: address(0)})
        );
    }

    /// Test successful initialization sets all storage correctly.
    function testInitializeSuccess(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);

        assertEq(oracle.st0xToken(), st0xToken);
        assertEq(oracle.priceId(), priceId);
        assertEq(oracle.maxAge(), maxAge);
        assertEq(oracle.admin(), admin);
        assertEq(oracle.paused(), false);
        assertEq(oracle.decimals(), 8);
        assertEq(oracle.version(), 1);
    }

    /// Test that PythOracleAdapterInitialized event is emitted.
    function testInitializeEvent(address st0xToken, bytes32 priceId, uint256 maxAge, address admin) external {
        vm.assume(st0xToken != address(0));
        vm.assume(priceId != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        vm.recordLogs();
        PythOracleAdapter oracle = createOracle(st0xToken, priceId, maxAge, admin);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool eventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256("PythOracleAdapterInitialized(address,(address,bytes32,uint256,address))")
            ) {
                // sender is indexed, so it's in topics[1].
                address sender = address(uint160(uint256(logs[i].topics[1])));
                PythOracleAdapterConfig memory config = abi.decode(logs[i].data, (PythOracleAdapterConfig));
                assertEq(sender, address(I_DEPLOYER));
                assertEq(config.st0xToken, st0xToken);
                assertEq(config.priceId, priceId);
                assertEq(config.maxAge, maxAge);
                assertEq(config.admin, admin);
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound, "PythOracleAdapterInitialized event not found");
        assertTrue(address(oracle) != address(0));
    }

    /// Test that deploying multiple oracles produces independent proxies.
    function testInitializeMultipleOracles(
        address st0xTokenA,
        bytes32 priceIdA,
        address st0xTokenB,
        bytes32 priceIdB,
        uint256 maxAge,
        address admin
    ) external {
        vm.assume(st0xTokenA != address(0));
        vm.assume(st0xTokenB != address(0));
        vm.assume(priceIdA != bytes32(0));
        vm.assume(priceIdB != bytes32(0));
        vm.assume(maxAge > 0);
        vm.assume(admin != address(0));

        PythOracleAdapter oracleA = createOracle(st0xTokenA, priceIdA, maxAge, admin);
        PythOracleAdapter oracleB = createOracle(st0xTokenB, priceIdB, maxAge, admin);

        assertTrue(address(oracleA) != address(oracleB));
        assertEq(oracleA.st0xToken(), st0xTokenA);
        assertEq(oracleB.st0xToken(), st0xTokenB);
        assertEq(oracleA.priceId(), priceIdA);
        assertEq(oracleB.priceId(), priceIdB);
    }
}
