// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {LibFork} from "test/lib/LibFork.sol";
import {
    PythOracleAdapter,
    PythOracleAdapterConfig
} from "src/concrete/oracle/PythOracleAdapter.sol";
import {
    PythOracleAdapterBeaconSetDeployer,
    PythOracleAdapterBeaconSetDeployerConfig
} from "src/concrete/deploy/PythOracleAdapterBeaconSetDeployer.sol";

/// @dev TSLA/USD Pyth price feed ID.
bytes32 constant PRICE_FEED_ID_EQUITY_US_TSLA_USD = 0x16dad506d7db8da01c87581c87ca897a012a153557d4d578c3b9c9e1bc0632f1;

/// @dev Base chain ID.
uint256 constant BASE_CHAIN_ID = 8453;

contract PythOracleAdapterLatestAnswerTest is Test {
    PythOracleAdapterBeaconSetDeployer internal immutable I_DEPLOYER;

    constructor() {
        LibFork.createSelectForkBase(vm);

        PythOracleAdapter implementation = new PythOracleAdapter();
        I_DEPLOYER = new PythOracleAdapterBeaconSetDeployer(
            PythOracleAdapterBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialPythOracleAdapterImplementation: address(implementation)
            })
        );
    }

    function setUp() external {
        vm.chainId(BASE_CHAIN_ID);
    }

    /// Test that latestAnswer returns a positive price on a real Base fork.
    function testLatestAnswerBaseFork() external {
        PythOracleAdapter oracle = I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({
                st0xToken: address(uint160(uint256(keccak256("st0x.tsla")))),
                priceId: PRICE_FEED_ID_EQUITY_US_TSLA_USD,
                maxAge: 3600,
                admin: address(this)
            })
        );

        int256 answer = oracle.latestAnswer();
        assertTrue(answer > 0, "Price should be positive");
        // TSLA price should be in a reasonable range at 8 decimals.
        // At block 38996123, TSLA was roughly $440.
        assertTrue(answer > 100e8, "Price too low for TSLA");
        assertTrue(answer < 100_000e8, "Price too high for TSLA");
    }

    /// Test that latestRoundData returns consistent data.
    function testLatestRoundDataBaseFork() external {
        PythOracleAdapter oracle = I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({
                st0xToken: address(uint160(uint256(keccak256("st0x.tsla")))),
                priceId: PRICE_FEED_ID_EQUITY_US_TSLA_USD,
                maxAge: 3600,
                admin: address(this)
            })
        );

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answeredInRound, 1);
        assertTrue(answer > 0, "Price should be positive");
        assertTrue(startedAt > 0, "startedAt should be nonzero");
        assertEq(startedAt, updatedAt);

        // Answer from latestRoundData should match latestAnswer.
        assertEq(answer, oracle.latestAnswer());
    }

    /// Test that decimals returns 8.
    function testDecimalsBaseFork() external {
        PythOracleAdapter oracle = I_DEPLOYER.newPythOracleAdapter(
            PythOracleAdapterConfig({
                st0xToken: address(uint160(uint256(keccak256("st0x.tsla")))),
                priceId: PRICE_FEED_ID_EQUITY_US_TSLA_USD,
                maxAge: 3600,
                admin: address(this)
            })
        );

        assertEq(oracle.decimals(), 8);
    }
}
