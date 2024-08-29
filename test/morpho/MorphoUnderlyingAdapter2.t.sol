// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AggregatorInterface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorInterface.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {MorphoUnderlyingAdapter} from "src/adapters/MorphoUnderlyingAdapter.sol";
import {VaultSharesOracle} from "src/adapters/VaultSharesOracle.sol";
import {Stablecoin} from "src/Stablecoin.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC4626Mock} from "openzeppelin-contracts/contracts/mocks/ERC4626Mock.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract MockAggregator is AggregatorInterface {
    uint256 public latestRound;
    uint256 public latestTimestamp;

    int256 public latestAnswer;
    uint256 public updatedAt;

    function latestRoundData()
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, latestAnswer, 0, updatedAt, 0);
    }

    function setLatestAnswer(int256 answer) public {
        latestAnswer = answer;
        updatedAt = block.timestamp;
    }

    function getAnswer(uint256) external pure returns (int256) {
        return 0;
    }

    function getTimestamp(uint256) external pure returns (uint256) {
        return 0;
    }
}

contract MorphoUnderlyingAdapterTest is Test {
    MorphoUnderlyingAdapter public adapter;
    VaultSharesOracle public vaultSharesOracle;
    MockAggregator public mockAggregator;
    ERC4626Mock public mockVault;
    ERC20 public underlying;

    function setUp() external {
        mockAggregator = new MockAggregator();

        underlying = new ERC20DecimalsMock("UnderlyingMock", "UND", 6);

        mockVault = new ERC4626Mock(
            underlying,
            "UnderlyingMock Vault",
            "UND_V"
        );

        vaultSharesOracle = new VaultSharesOracle(
            AggregatorV3Interface(address(mockAggregator)),
            mockVault
        );

        adapter = new MorphoUnderlyingAdapter(
            address(this),
            address(underlying),
            address(mockVault),
            address(mockAggregator),
            address(vaultSharesOracle),
            1 days
        );
        adapter.grantRole(adapter.CONTROLLER(), address(this));
        adapter.grantRole(adapter.MANAGER(), address(this));
    }

    function testFlow() external {
        mockAggregator.setLatestAnswer(1e8);

        deal(address(underlying), address(this), 100_000e6, true);

        underlying.approve(address(adapter), 100_000e6);

        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.allocate(100_000e6);

        assertEq(adapter.underlyingBalance(), 100_000e6);
        assertEq(adapter.underlyingTotalValue(), 100_000e18);
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.setUnderlyingRiskWeight(0.2e6);

        assertEq(adapter.underlyingBalance(), 100_000e6);
        assertEq(adapter.underlyingTotalValue(), 100_000e18);
        assertEq(adapter.underlyingTotalRiskValue(), 20_000e18);
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        mockAggregator.setLatestAnswer(0.975e8);

        assertEq(adapter.underlyingBalance(), 100_000e6);
        assertEq(adapter.underlyingTotalValue(), (100_000e18 * 0.975e8) / 1e8);
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (20_000e18 * 0.975e8) / 1e8
        );
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.withdraw(20_000e6);
        mockAggregator.setLatestAnswer(1.05e8);

        assertEq(adapter.underlyingBalance(), 80_000e6);
        assertEq(adapter.underlyingTotalValue(), (80_000e18 * 1.05e8) / 1e8);
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (16_000e18 * 1.05e8) / 1e8
        );
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.deposit(10_000e6);

        assertEq(adapter.underlyingBalance(), 70_000e6);
        assertEq(adapter.underlyingTotalValue(), (70_000e18 * 1.05e8) / 1e8);
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (14_000e18 * 1.05e8) / 1e8
        );
        assertEq(adapter.fundBalance(), 10_000e6);
        assertEq(adapter.fundTotalValue(), (10_000e18 * 1.05e8) / 1e8);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.setFundRiskWeight(0.15e6);

        assertEq(adapter.underlyingBalance(), 70_000e6);
        assertEq(adapter.underlyingTotalValue(), (70_000e18 * 1.05e8) / 1e8);
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (14_000e18 * 1.05e8) / 1e8
        );
        assertEq(adapter.fundBalance(), 10_000e6);
        assertEq(adapter.fundTotalValue(), (10_000e18 * 1.05e8) / 1e8);
        assertEq(adapter.fundTotalRiskValue(), (1_500e18 * 1.05e8) / 1e8);

        // Extra 2'000 has been generated by yield in the vault
        deal(address(underlying), address(mockVault), 12_000e6, true);

        assertEq(adapter.underlyingBalance(), 70_000e6);
        assertEq(adapter.underlyingTotalValue(), (70_000e18 * 1.05e8) / 1e8);
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (14_000e18 * 1.05e8) / 1e8
        );
        assertEq(adapter.fundBalance(), 10_000e6);
        assertEq(adapter.fundTotalValue(), (12_000e18 * 1.05e8) / 1e8);
        assertEq(adapter.fundTotalRiskValue(), (1_800e18 * 1.05e8) / 1e8);

        adapter.withdraw(70_000e6);
        mockAggregator.setLatestAnswer(0.8e8);

        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.fundBalance(), 10_000e6);
        assertEq(adapter.fundTotalValue(), (12_000e18 * 0.8e8) / 1e8);
        assertEq(adapter.fundTotalRiskValue(), (1_800e18 * 0.8e8) / 1e8);

        adapter.redeem(5_000e6);
        adapter.setFundRiskWeight(0.1e6);
        adapter.setUnderlyingRiskWeight(0.05e6);

        assertEq(adapter.underlyingBalance(), 6_000e6);
        assertEq(adapter.underlyingTotalValue(), (6_000e18 * 0.8e8) / 1e8);
        assertEq(adapter.underlyingTotalRiskValue(), (300e18 * 0.8e8) / 1e8);
        assertEq(adapter.fundBalance(), 5_000e6);
        assertEq(adapter.fundTotalValue(), (6_000e18 * 0.8e8) / 1e8);
        assertEq(adapter.fundTotalRiskValue(), (600e18 * 0.8e8) / 1e8);

        // Extra 1'000 has been generated by yield in the vault
        deal(address(underlying), address(mockVault), 7_000e6, true);

        adapter.redeem(5_000e6);

        assertEq(adapter.underlyingBalance(), 13_000e6);
        assertEq(adapter.underlyingTotalValue(), (13_000e18 * 0.8e8) / 1e8);
        assertEq(adapter.underlyingTotalRiskValue(), (650e18 * 0.8e8) / 1e8);
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);

        adapter.withdraw(13_000e6);

        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.fundBalance(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundTotalRiskValue(), 0);
    }
}
