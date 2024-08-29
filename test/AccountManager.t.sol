// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {ITerm, Term} from "src/Term.sol";
import {ITermIssuer, TermIssuer} from "src/TermIssuer.sol";

import {ISavingModule, SavingModule} from "src/SavingModule.sol";
import {IPegStabilityModule, PegStabilityModule} from "src/PegStabilityModule.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {ICreditEnforcer, CreditEnforcer} from "src/CreditEnforcer.sol";

import {AccountManager} from "src/AccountManager.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract AccountManagerTest is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    Stablecoin rusd;
    Savingcoin srusd;

    Term term;
    TermIssuer termIssuer;

    SavingModule sm;
    PegStabilityModule psm;

    CreditEnforcer creditEnforcer;

    AccountManager accountManager;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc.mint(eoa1, 10_000_000e6);
        usdc.mint(eoa2, 10_000_000e6);
        usdc.mint(address(this), 10_000_000e6);

        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        srusd = new Savingcoin(address(this), "Reservoir Savingcoin", "srUSD");

        term = new Term(address(this), "https://reservoir.io/terms/");

        // = = =

        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        rusd.grantRole(rusd.MINTER(), address(psm));

        // = = =

        termIssuer = new TermIssuer(
            address(this),
            91.25 days,
            0,
            ITerm(address(term)),
            IToken(address(rusd))
        );

        rusd.grantRole(rusd.MINTER(), address(termIssuer));
        term.grantRole(term.MINTER(), address(termIssuer));

        // = = =

        sm = new SavingModule(
            address(this),
            IToken(address(rusd)),
            IToken(address(srusd))
        );

        creditEnforcer = new CreditEnforcer(
            address(this),
            IERC20(address(usdc)),
            ITermIssuer(address(termIssuer)),
            IPegStabilityModule(address(psm)),
            ISavingModule(address(sm))
        );

        sm.grantRole(sm.CONTROLLER(), address(creditEnforcer));
        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        termIssuer.setDiscountRate(1, 0.00006859294e12);
        termIssuer.setDiscountRate(2, 0.00008217862e12);
        termIssuer.setDiscountRate(3, 0.00009574398e12);

        creditEnforcer.setDuration(30 days);

        // = = =

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.08e12
        );

        // = = =

        vm.prank(eoa1);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(psm), type(uint256).max);

        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa1);
        rusd.approve(address(accountManager), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(accountManager), type(uint256).max);

        rusd.approve(address(accountManager), type(uint256).max);

        psm.allocate(1_000_000e6);
    }

    function testInitialState() external {
        assertEq(address(accountManager.rusd()), address(rusd));
        assertEq(address(accountManager.termIssuer()), address(termIssuer));

        assertEq(
            address(accountManager.creditEnforcer()),
            address(creditEnforcer)
        );

        assertEq(accountManager.couponRate(), 0.08e12);
    }

    function testQuote() external {
        uint256 cost;
        uint256 profit;

        (cost, profit) = accountManager.getQuote(3, 1_000_000e18);

        assertGt(profit, 0);
        assertEq(profit, 1_060_000e18 - cost);

        skip(180 days);

        (cost, profit) = accountManager.getQuote(3, 1_000_000e18);

        assertGt(profit, 0);
        assertEq(profit, 1_040_000e18 - cost);

        vm.warp(termIssuer.maturityTimestamp(3));

        (cost, profit) = accountManager.getQuote(3, 1_000_000e18);

        assertEq(profit, 0);
        assertEq(cost, type(uint256).max);
    }

    // * testInvalidIssue
    // * testSuccessfulIssue

    function testIssue() external {
        uint256 cost;
        uint256 profit;

        AccountManager.Position memory position;

        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(2_000_000e6);

        assertEq(rusd.balanceOf(address(accountManager)), 0);

        assertEq(term.balanceOf(address(accountManager), 1), 0);
        assertEq(term.balanceOf(address(accountManager), 2), 0);
        assertEq(term.balanceOf(address(accountManager), 3), 0);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);

        vm.prank(eoa1);
        accountManager.mintTerm(3, 1_000_000e18);

        assertEq(rusd.balanceOf(address(accountManager)), 0);

        assertEq(term.balanceOf(address(accountManager), 1), 20_000e18);
        assertEq(term.balanceOf(address(accountManager), 2), 20_000e18);
        assertEq(term.balanceOf(address(accountManager), 3), 1_020_000e18);

        (cost, profit) = accountManager.getQuote(3, 1_000_000e18);

        assertEq(2_000_000e18 - rusd.balanceOf(eoa1), cost);
        assertEq(1_060_000e18 + rusd.balanceOf(eoa1) - 2_000_000e18, profit);

        vm.prank(eoa1);
        accountManager.mintTerm(eoa2, 3, 100_000e18);

        position = accountManager.getUserPosition(eoa1, 3);

        assertEq(position.coupons[0], 20_000e18);
        assertEq(position.coupons[1], 20_000e18);
        assertEq(position.coupons[2], 20_000e18);

        assertEq(position.principle, 1_000_000e18);

        position = accountManager.getUserPosition(eoa2, 3);

        assertEq(position.coupons[0], 2_000e18);
        assertEq(position.coupons[1], 2_000e18);
        assertEq(position.coupons[2], 2_000e18);

        assertEq(position.principle, 100_000e18);
    }

    // * testInvalidClaim
    // * testSuccessfulClaim

    function testClaim() external {
        uint256 rusdBalance;

        AccountManager.Position memory position;

        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(2_000_000e6);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);

        vm.prank(eoa1);
        accountManager.mintTerm(3, 1_000_000e18);

        position = accountManager.getUserPosition(eoa1, 3);

        assertEq(position.coupons[0], 20_000e18);
        assertEq(position.coupons[1], 20_000e18);
        assertEq(position.coupons[2], 20_000e18);

        assertEq(position.coupons.length, 3);
        assertEq(position.principle, 1_000_000e18);

        vm.expectRevert("AM: no coupon available");

        vm.prank(eoa1);
        accountManager.claim(3);

        skip(91.25 days);

        rusdBalance = rusd.balanceOf(eoa1);

        vm.prank(eoa1);
        accountManager.claim(3);

        position = accountManager.getUserPosition(eoa1, 3);

        assertEq(position.coupons[0], 20_000e18);
        assertEq(position.coupons[1], 20_000e18);

        assertEq(position.coupons.length, 2);
        assertEq(position.principle, 1_000_000e18);

        assertEq(rusd.balanceOf(eoa1), rusdBalance + 20_000e18);
        assertEq(term.balanceOf(address(accountManager), 1), 0);

        skip(91.25 days);

        vm.prank(eoa1);
        accountManager.claim(eoa2, 3);

        position = accountManager.getUserPosition(eoa1, 3);

        assertEq(position.coupons[0], 20_000e18);

        assertEq(position.coupons.length, 1);
        assertEq(position.principle, 1_000_000e18);

        assertEq(rusd.balanceOf(eoa2), 20_000e18);
        assertEq(term.balanceOf(address(accountManager), 2), 0);

        skip(91.25 days);

        rusdBalance = rusd.balanceOf(eoa1);

        vm.prank(eoa1);
        accountManager.claim(3);

        position = accountManager.getUserPosition(eoa1, 3);

        assertEq(position.coupons.length, 0);
        assertEq(position.principle, 1_000_000e18);

        assertEq(rusd.balanceOf(eoa1), rusdBalance + 20_000e18);
        assertEq(term.balanceOf(address(accountManager), 3), 1_000_000e18);
    }

    // * testInvalidRedeem
    // * testSuccessfulRedeem

    function testRedeem() external {
        uint256 cost;
        uint256 profit;

        AccountManager.Position memory position;

        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(2_000_000e6);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);

        vm.prank(eoa1);
        accountManager.mintTerm(1, 1_000_000e18);

        position = accountManager.getUserPosition(eoa1, 1);
        (cost, profit) = accountManager.getQuote(1, 1_000_000e18);

        assertEq(position.coupons[0], 20_000e18);

        assertEq(position.coupons.length, 1);
        assertEq(position.principle, 1_000_000e18);

        vm.expectRevert("AM: all coupons must be claimed");

        vm.prank(eoa1);
        accountManager.redeem(1);

        skip(91.25 days);

        vm.prank(eoa1);
        accountManager.claim(1);

        vm.prank(eoa1);
        accountManager.redeem(1);

        assertEq(rusd.balanceOf(eoa1), 2_000_000e18 + profit);
        assertEq(term.balanceOf(address(accountManager), 1), 0);

        creditEnforcer.setTermDebtMax(2, type(uint256).max);

        vm.prank(eoa1);
        accountManager.mintTerm(2, 1_000_000e18);

        skip(91.25 days);

        vm.prank(eoa1);
        accountManager.claim(eoa2, 2);

        vm.prank(eoa1);
        accountManager.redeem(eoa2, 2);

        assertEq(rusd.balanceOf(eoa2), 1_020_000e18);
        assertEq(term.balanceOf(address(accountManager), 2), 0);
    }
}
