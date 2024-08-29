// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {AssetPrice, AssetAdapter} from "src/adapters/AssetAdapter.sol";

import {MockFund} from "test/mocks/MockFund.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

contract AssetAdapterTest is Test {
    event Deposit(address, uint256);

    event Redemption(address, uint256);

    AssetPrice assetPrice;
    MockV3Aggregator usdcAggregator;

    MockFund mockFund;

    AssetAdapter assetAdapter;

    function setUp() external {
        mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        ERC20DecimalsMock usdc = new ERC20DecimalsMock(
            "USD Coin Mock",
            "USDC",
            6
        );

        assetPrice = new AssetPrice(address(mockFund));
        usdcAggregator = new MockV3Aggregator(8, 1e8);

        assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        vm.etch(address(assetAdapter.underlying()), address(usdc).code);

        assetAdapter.grantRole(assetAdapter.MANAGER(), address(this));
        assetAdapter.grantRole(assetAdapter.CONTROLLER(), address(this));

        ERC20DecimalsMock(address(assetAdapter.underlying())).mint(
            address(this),
            1_000_000e6
        );

        IERC20(address(assetAdapter.underlying())).approve(
            address(assetAdapter),
            type(uint256).max
        );
    }

    function testInitialState() external {
        assertTrue(assetAdapter.hasRole(0x0, address(this)));
        assertTrue(
            assetAdapter.hasRole(assetAdapter.CONTROLLER(), address(this))
        );

        assertEq(
            address(assetAdapter.underlyingPriceOracle()),
            address(usdcAggregator)
        );
        assertEq(address(assetAdapter.fundPriceOracle()), address(assetPrice));

        assertEq(assetAdapter.underlyingRiskWeight(), 0e6);
        assertEq(assetAdapter.fundRiskWeight(), 0e6);
    }

    function testDeposit() external {
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(assetAdapter), 1_000e6);

        assetAdapter.deposit(1_000e6);

        assertEq(
            IERC20(assetAdapter.underlying()).allowance(
                address(assetAdapter),
                address(mockFund)
            ),
            1_000e6
        );

        uint256 userDeposits;
        (, userDeposits) = mockFund.userDeposits(address(assetAdapter));

        assertEq(userDeposits, 1_000e6);
        assertEq(mockFund.totalDeposits(), 1_000e6);
    }

    function testRedeem() external {
        vm.expectEmit(true, true, true, true);
        emit Redemption(address(assetAdapter), 1_000e18);

        assetAdapter.redeem(1_000e18);

        assertEq(
            IERC20(assetAdapter.fund()).allowance(
                address(assetAdapter),
                address(mockFund)
            ),
            1_000e18
        );

        uint256 userRedemptions;
        (, userRedemptions) = mockFund.userRedemptions(address(assetAdapter));

        assertEq(userRedemptions, 1_000e18);
        assertEq(mockFund.totalRedemptions(), 1_000e18);
    }

    function testUSDCCalcs() external {
        assertEq(assetAdapter.underlyingRiskWeight(), 0e6);

        assertEq(assetAdapter.underlyingBalance(), 0);

        assertEq(assetAdapter.underlyingValue(0), 0e18);
        assertEq(assetAdapter.underlyingRiskValue(0), 0e18);

        assertEq(assetAdapter.underlyingTotalValue(), 0e18);
        assertEq(assetAdapter.underlyingTotalRiskValue(), 0e18);

        usdcAggregator.updateAnswer(0.95e8);

        assetAdapter.allocate(1_000e6);

        assertEq(assetAdapter.underlyingBalance(), 1_000e6);

        assertEq(assetAdapter.underlyingValue(1_000e6), 950e18);
        assertEq(assetAdapter.underlyingRiskValue(1_000e6), 0e18);

        assertEq(assetAdapter.underlyingTotalValue(), 950e18);
        assertEq(assetAdapter.underlyingTotalRiskValue(), 0e18);

        assetAdapter.setUnderlyingRiskWeight(0.1e6);

        vm.prank(address(assetAdapter));
        mockFund.deposit(1_000e6);

        assertEq(assetAdapter.underlyingBalance(), 1_000e6);

        assertEq(assetAdapter.underlyingValue(1_000e6), 950e18);
        assertEq(assetAdapter.underlyingRiskValue(1_000e6), 95e18);

        assertEq(assetAdapter.underlyingTotalValue(), 1_900e18);
        assertEq(assetAdapter.underlyingTotalRiskValue(), 190e18);

        // TODO: Test withdraw
    }

    function testFundCalcs() external {
        mockFund.updatePrice(1.0e8);

        assertEq(assetAdapter.fundRiskWeight(), 0e6);

        assertEq(assetAdapter.fundBalance(), 0e18);

        assertEq(assetAdapter.fundValue(0), 0e18);
        assertEq(assetAdapter.fundRiskValue(0), 0e18);

        assertEq(assetAdapter.fundTotalValue(), 0e18);
        assertEq(assetAdapter.fundTotalRiskValue(), 0e18);

        mockFund.updatePrice(2.0e8);

        mockFund.mint(address(assetAdapter), 100e18);

        assetAdapter.allocate(1_000e6);

        assertEq(assetAdapter.fundBalance(), 100e18);

        assertEq(assetAdapter.fundValue(100e18), 200e18);
        assertEq(assetAdapter.fundRiskValue(100e18), 0e18);

        assertEq(assetAdapter.fundTotalValue(), 200e18);
        assertEq(assetAdapter.fundTotalRiskValue(), 0e18);

        assetAdapter.setFundRiskWeight(0.4e6);

        vm.prank(address(assetAdapter));
        mockFund.redeem(100e18);

        assertEq(assetAdapter.fundBalance(), 100e18);

        assertEq(assetAdapter.fundValue(100e18), 200e18);
        assertEq(assetAdapter.fundRiskValue(100e18), 80e18);

        assertEq(assetAdapter.fundTotalValue(), 400e18);
        assertEq(assetAdapter.fundTotalRiskValue(), 160e18);

        // TODO: Test withdraw
    }

    // TODO: Add test for total value

    // TODO: Add test for withdraw
}
