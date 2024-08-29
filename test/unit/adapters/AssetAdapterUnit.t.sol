// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {AssetPrice, AssetAdapter} from "src/adapters/AssetAdapter.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

import {OffchainFund} from "offchain-fund/src/OffchainFund.sol";

contract AssetAdapterUnitTest is Test {
    ERC20DecimalsMock usdc;
    AssetPrice assetPrice;
    MockV3Aggregator usdcAggregator;

    OffchainFund fund;

    AssetAdapter assetAdapter;

    uint256 public constant MAX_USDC_AMOUNT = 1e24;
    uint256 public constant MAX_FUND_AMOUNT = 1e30;

    uint256 public constant INITIAL_DURATION = 30 days;

    function setUp() external {
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        fund = new OffchainFund(
            address(this),
            address(usdc),
            "Treasury Bills",
            "TBILL"
        );

        fund.adjustCap(type(uint256).max);
        fund.adjustMin(0);

        assetPrice = new AssetPrice(address(fund));
        usdcAggregator = new MockV3Aggregator(8, 1e8);

        assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(fund),
            address(usdcAggregator),
            address(assetPrice),
            INITIAL_DURATION
        );

        vm.etch(address(assetAdapter.underlying()), address(usdc).code);

        assetAdapter.grantRole(assetAdapter.MANAGER(), address(this));
        assetAdapter.grantRole(assetAdapter.CONTROLLER(), address(this));

        fund.addToWhitelist(address(assetAdapter));
    }

    function testInitialState() external {
        assertTrue(assetAdapter.hasRole(0x0, address(this)));
        assertTrue(
            assetAdapter.hasRole(assetAdapter.CONTROLLER(), address(this))
        );

        assertEq(assetAdapter.duration(), INITIAL_DURATION);

        assertEq(
            address(assetAdapter.underlyingPriceOracle()),
            address(usdcAggregator)
        );
        assertEq(address(assetAdapter.fundPriceOracle()), address(assetPrice));

        assertEq(assetAdapter.underlyingRiskWeight(), 0e6);
        assertEq(assetAdapter.fundRiskWeight(), 0e6);

        assertEq(address(assetAdapter.underlying()), address(usdc));

        assertEq(address(assetAdapter.fund()), address(fund));
        assertTrue(fund.isWhitelisted(address(assetAdapter)));
    }

    function testAllocate(uint256 amount) external {
        usdc.mint(address(this), amount);

        assertEq(usdc.balanceOf(address(assetAdapter)), 0);

        usdc.approve(address(assetAdapter), amount);
        assetAdapter.allocate(amount);

        assertEq(usdc.balanceOf(address(assetAdapter)), amount);
        assertEq(usdc.balanceOf(address(this)), 0);
    }

    function testAllocateWithInsufficientAllowance(uint256 amount) external {
        vm.assume(amount > 0);

        usdc.mint(address(this), amount);

        vm.expectRevert("ERC20: insufficient allowance");
        assetAdapter.allocate(amount);
    }

    function testAllocateWithInsufficientBalance(uint256 amount) external {
        vm.assume(amount > 0);

        usdc.approve(address(assetAdapter), amount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        assetAdapter.allocate(amount);
    }

    function testWithdraw(
        uint256 allocateAmount,
        uint256 withdrawAmount
    ) external {
        vm.assume(allocateAmount >= withdrawAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assetAdapter.withdraw(withdrawAmount);

        assertEq(
            usdc.balanceOf(address(assetAdapter)),
            allocateAmount - withdrawAmount
        );
        assertEq(usdc.balanceOf(address(this)), withdrawAmount);
    }

    function testWithdrawInsufficientBalance(
        uint256 allocateAmount,
        uint256 withdrawAmount
    ) external {
        vm.assume(allocateAmount < withdrawAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        assetAdapter.withdraw(withdrawAmount);
    }

    function testWithdrawUnauthorized(
        uint256 allocateAmount,
        uint256 withdrawAmount,
        address wallet
    ) external {
        vm.assume(allocateAmount > 0 && withdrawAmount > 0);
        vm.assume(wallet != address(this));

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        vm.expectRevert();
        vm.prank(wallet);
        assetAdapter.withdraw(withdrawAmount);
    }

    function testDeposit(
        uint256 allocateAmount,
        uint256 depositAmount
    ) external {
        vm.assume(allocateAmount > 0);
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount <= allocateAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assetAdapter.deposit(depositAmount);

        assertEq(
            usdc.balanceOf(address(assetAdapter)),
            allocateAmount - depositAmount
        );
        assertEq(usdc.balanceOf(address(fund)), depositAmount);
        assertEq(usdc.balanceOf(address(this)), 0);
    }

    function testDepositInsufficientBalance(
        uint256 allocateAmount,
        uint256 depositAmount
    ) external {
        vm.assume(allocateAmount > 0);
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount > allocateAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        assetAdapter.deposit(depositAmount);
    }

    function testDepositUnauthorized(uint256 amount, address wallet) external {
        vm.assume(amount > 0);
        vm.assume(wallet != address(this));

        usdc.mint(address(this), amount);

        usdc.approve(address(assetAdapter), amount);
        assetAdapter.allocate(amount);

        vm.expectRevert();
        vm.prank(address(1));
        assetAdapter.deposit(amount);
    }

    function testRedeem(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assetAdapter.deposit(depositAmount);

        _processFundDeposit();

        assetAdapter.redeem(redeemAmount * 1e12);

        _processFundRedeem();

        assertEq(
            usdc.balanceOf(address(assetAdapter)),
            allocateAmount - depositAmount + redeemAmount
        );
        assertEq(usdc.balanceOf(address(fund)), depositAmount - redeemAmount);
        assertEq(usdc.balanceOf(address(this)), 0);
    }

    function testRedeemInsufficientBalance(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount > depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assetAdapter.deposit(depositAmount);

        _processFundDeposit();

        vm.expectRevert("ERC20: burn amount exceeds balance");
        assetAdapter.redeem(redeemAmount * 1e12);
    }

    function testRedeemUnauthorized(uint256 amount, address wallet) external {
        vm.assume(amount > 0 && amount < MAX_USDC_AMOUNT);
        vm.assume(wallet != address(this));

        usdc.mint(address(this), amount);

        usdc.approve(address(assetAdapter), amount);
        assetAdapter.allocate(amount);

        assetAdapter.deposit(amount);

        _processFundDeposit();

        vm.expectRevert();
        vm.prank(wallet);
        assetAdapter.redeem(amount * 1e12);
    }

    function testSetUSDCRiskWeight(uint256 riskWeight) external {
        if (riskWeight < 1e6) {
            assetAdapter.setUnderlyingRiskWeight(riskWeight);
            assertEq(assetAdapter.underlyingRiskWeight(), riskWeight);
        } else {
            vm.expectRevert("FA: Risk Weight can not be above 100%");
            assetAdapter.setUnderlyingRiskWeight(riskWeight);
        }
    }

    function testSetUSDCRiskWeightUnauthorized(
        uint256 riskWeight,
        address wallet
    ) external {
        vm.assume(wallet != address(this));

        vm.prank(wallet);
        vm.expectRevert();
        assetAdapter.setUnderlyingRiskWeight(riskWeight);
    }

    function testSetFundRiskWeight(uint256 riskWeight) external {
        if (riskWeight < 1e6) {
            assetAdapter.setFundRiskWeight(riskWeight);
            assertEq(assetAdapter.fundRiskWeight(), riskWeight);
        } else {
            vm.expectRevert("FA: Risk Weight can not be above 100%");
            assetAdapter.setFundRiskWeight(riskWeight);
        }
    }

    function testSetFundRiskWeightUnauthorized(
        uint256 riskWeight,
        address wallet
    ) external {
        vm.assume(wallet != address(this));

        vm.prank(wallet);
        vm.expectRevert();
        assetAdapter.setFundRiskWeight(riskWeight);
    }

    function testTotalValue(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.totalValue(), allocateAmount * 1e12);

        assetAdapter.deposit(depositAmount);

        assertEq(assetAdapter.totalValue(), allocateAmount * 1e12);

        _processFundDeposit();

        assertEq(assetAdapter.totalValue(), allocateAmount * 1e12);

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(assetAdapter.totalValue(), allocateAmount * 1e12);

        _processFundRedeem();

        assertEq(assetAdapter.totalValue(), allocateAmount * 1e12);
    }

    function testTotalRiskValue(
        uint256 usdcRiskValue,
        uint256 fundRiskValue,
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);
        vm.assume(usdcRiskValue > 0 && usdcRiskValue < 1e6);
        vm.assume(fundRiskValue > 0 && fundRiskValue < 1e6);

        assetAdapter.setUnderlyingRiskWeight(usdcRiskValue);
        assetAdapter.setFundRiskWeight(fundRiskValue);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(
            assetAdapter.totalRiskValue(),
            (allocateAmount * 1e12 * assetAdapter.underlyingRiskWeight()) / 1e6
        );

        assetAdapter.deposit(depositAmount);

        assertEq(
            assetAdapter.totalRiskValue(),
            (allocateAmount * 1e12 * assetAdapter.underlyingRiskWeight()) / 1e6
        );

        _processFundDeposit();

        assertEq(
            assetAdapter.totalRiskValue(),
            ((allocateAmount - depositAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) /
                1e6 +
                ((depositAmount * 1e12 * assetAdapter.fundRiskWeight()) / 1e6)
        );

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.totalRiskValue(),
            ((allocateAmount - depositAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) /
                1e6 +
                ((depositAmount * 1e12 * assetAdapter.fundRiskWeight()) / 1e6)
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.totalRiskValue(),
            ((allocateAmount - depositAmount + redeemAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) /
                1e6 +
                (((depositAmount - redeemAmount) *
                    1e12 *
                    assetAdapter.fundRiskWeight()) / 1e6)
        );
    }

    function testUsdcTotalRiskValue(
        uint256 usdcRiskValue,
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);
        vm.assume(usdcRiskValue > 0 && usdcRiskValue < 1e6);

        assetAdapter.setUnderlyingRiskWeight(usdcRiskValue);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(
            assetAdapter.underlyingTotalRiskValue(),
            (allocateAmount * 1e12 * assetAdapter.underlyingRiskWeight()) / 1e6
        );

        assetAdapter.deposit(depositAmount);

        assertEq(
            assetAdapter.underlyingTotalRiskValue(),
            (allocateAmount * 1e12 * assetAdapter.underlyingRiskWeight()) / 1e6
        );

        _processFundDeposit();

        assertEq(
            assetAdapter.underlyingTotalRiskValue(),
            ((allocateAmount - depositAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) / 1e6
        );

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.underlyingTotalRiskValue(),
            ((allocateAmount - depositAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) / 1e6
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.underlyingTotalRiskValue(),
            ((allocateAmount - depositAmount + redeemAmount) *
                1e12 *
                assetAdapter.underlyingRiskWeight()) / 1e6
        );
    }

    function testFundTotalRiskValue(
        uint256 fundRiskValue,
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);
        vm.assume(fundRiskValue > 0 && fundRiskValue < 1e6);

        assetAdapter.setFundRiskWeight(fundRiskValue);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.fundTotalRiskValue(), 0);

        assetAdapter.deposit(depositAmount);

        assertEq(assetAdapter.fundTotalRiskValue(), 0);

        _processFundDeposit();

        assertEq(
            assetAdapter.fundTotalRiskValue(),
            (depositAmount * 1e12 * assetAdapter.fundRiskWeight()) / 1e6
        );

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.fundTotalRiskValue(),
            (depositAmount * 1e12 * assetAdapter.fundRiskWeight()) / 1e6
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.fundTotalRiskValue(),
            ((depositAmount - redeemAmount) *
                1e12 *
                assetAdapter.fundRiskWeight()) / 1e6
        );
    }

    function testUsdcRiskValue(uint256 usdcRiskValue, uint256 amount) external {
        vm.assume(usdcRiskValue > 0 && usdcRiskValue < 1e6);
        vm.assume(amount > 0 && amount < MAX_USDC_AMOUNT);

        assetAdapter.setUnderlyingRiskWeight(usdcRiskValue);

        assertEq(
            assetAdapter.underlyingRiskValue(amount),
            (amount * 1e12 * usdcRiskValue) / 1e6
        );
    }

    function testFundRiskValue(uint256 fundRiskValue, uint256 amount) external {
        vm.assume(fundRiskValue > 0 && fundRiskValue < 1e6);
        vm.assume(amount > 0 && amount < MAX_USDC_AMOUNT);

        assetAdapter.setFundRiskWeight(fundRiskValue);

        assertEq(
            assetAdapter.fundRiskValue(amount),
            (amount * fundRiskValue) / 1e6
        );
    }

    function testUsdcTotalValue(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.underlyingTotalValue(), allocateAmount * 1e12);

        assetAdapter.deposit(depositAmount);

        assertEq(assetAdapter.underlyingTotalValue(), allocateAmount * 1e12);

        _processFundDeposit();

        assertEq(
            assetAdapter.underlyingTotalValue(),
            (allocateAmount - depositAmount) * 1e12
        );

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.underlyingTotalValue(),
            (allocateAmount - depositAmount) * 1e12
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.underlyingTotalValue(),
            (allocateAmount - depositAmount + redeemAmount) * 1e12
        );
    }

    function testFundTotalValue(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.fundTotalValue(), 0);

        assetAdapter.deposit(depositAmount);

        assertEq(assetAdapter.fundTotalValue(), 0);

        _processFundDeposit();

        assertEq(assetAdapter.fundTotalValue(), depositAmount * 1e12);

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(assetAdapter.fundTotalValue(), depositAmount * 1e12);

        _processFundRedeem();

        assertEq(
            assetAdapter.fundTotalValue(),
            (depositAmount - redeemAmount) * 1e12
        );
    }

    function testUsdcValue(uint256 amount) external {
        vm.assume(amount > 0 && amount < MAX_USDC_AMOUNT);

        assertEq(assetAdapter.underlyingValue(amount), amount * 1e12);
    }

    function testFundValue(uint256 amount) external {
        vm.assume(amount > 0 && amount < MAX_USDC_AMOUNT);

        assertEq(assetAdapter.fundValue(amount), amount);
    }

    function testUsdcBalance(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.underlyingBalance(), allocateAmount);

        assetAdapter.deposit(depositAmount);

        assertEq(
            assetAdapter.underlyingBalance(),
            allocateAmount - depositAmount
        );

        _processFundDeposit();

        assertEq(
            assetAdapter.underlyingBalance(),
            allocateAmount - depositAmount
        );

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.underlyingBalance(),
            allocateAmount - depositAmount
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.underlyingBalance(),
            allocateAmount - depositAmount + redeemAmount
        );
    }

    function testFundBalance(
        uint256 allocateAmount,
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(allocateAmount > 0 && allocateAmount < MAX_USDC_AMOUNT);
        vm.assume(depositAmount > 0 && depositAmount < MAX_USDC_AMOUNT);
        vm.assume(redeemAmount > 0 && redeemAmount < MAX_FUND_AMOUNT);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(assetAdapter), allocateAmount);
        assetAdapter.allocate(allocateAmount);

        assertEq(assetAdapter.fundBalance(), 0);

        assetAdapter.deposit(depositAmount);

        assertEq(assetAdapter.fundBalance(), 0);

        _processFundDeposit();

        assertEq(assetAdapter.fundBalance(), depositAmount * 1e12);

        assetAdapter.redeem(redeemAmount * 1e12);

        assertEq(
            assetAdapter.fundBalance(),
            (depositAmount - redeemAmount) * 1e12
        );

        _processFundRedeem();

        assertEq(
            assetAdapter.fundBalance(),
            (depositAmount - redeemAmount) * 1e12
        );
    }

    function _processFundDeposit() internal {
        uint256 fundPendingDeposits = fund.pendingDeposits();
        fund.drain();
        usdc.transfer(address(fund), fundPendingDeposits);
        fund.update(1e8);
        fund.processDeposit(address(assetAdapter));
    }

    function _processFundRedeem() internal {
        fund.drain();
        fund.update(1e8);
        fund.processRedeem(address(assetAdapter));
    }
}
