// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

contract E2ESDisableMintingTest is E2EMainTest {
    uint256 public constant COUPON_RATE = 0.08e12;
    uint256 public constant DISCOUNT_RATE = 0.000210874e12;

    address public eoa1 = vm.addr(1);
    address public eoa2 = vm.addr(2);
    address public eoa3 = vm.addr(3);

    function testDisableMinting() external {
        usdc.mint(address(psm), 1_000_000_000e6);

        // Set General Parameters
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e62108);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            COUPON_RATE
        );

        // Set Term Parameters
        for (
            uint256 i = termIssuer.earliestID();
            i <= termIssuer.latestID() + 10;
            i++
        ) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);

            termIssuer.setDiscountRate(i, DISCOUNT_RATE);
        }

        // Mint USDC to EOAs
        usdc.mint(eoa1, 1_000_000_000e6);
        usdc.mint(eoa2, 1_000_000_000e6);
        usdc.mint(eoa3, 1_000_000_000e6);

        // Mint rUSD to EOAs
        vm.prank(eoa1);
        usdc.approve(address(psm), 100_000_000e6);
        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa1, 100_000_000e6);
        vm.prank(eoa2);
        usdc.approve(address(psm), 100_000_000e6);
        vm.prank(eoa2);
        creditEnforcer.mintStablecoin(eoa2, 100_000_000e6);
        vm.prank(eoa3);
        usdc.approve(address(psm), 100_000_000e6);
        vm.prank(eoa3);
        creditEnforcer.mintStablecoin(eoa3, 100_000_000e6);

        _buyBond(eoa1, 100_000e18, 2);
        _buyBond(eoa3, 250_000e18, 2);

        skip(DELTA);

        _buyBond(eoa2, 800_000e18, 6);
        _buyBond(eoa2, 10_000e18, 2);

        _claimCoupon(eoa1, 2);
        _claimCoupon(eoa3, 2);

        _buyBond(eoa1, 300_000e18, 5);

        skip(DELTA);

        _claimCoupon(eoa1, 2);
        _redeemBond(eoa1, 2);

        _claimCoupon(eoa3, 2);
        _redeemBond(eoa3, 2);

        _claimCoupon(eoa1, 5);

        _claimCoupon(eoa2, 6);

        skip(DELTA);

        //? Current Situation:
        // eoa1: fully claimed and redeemed #2. 3 claims and redeem left for #5
        // eoa2: 1 claim and redeem left for #2. 4 claims and redeem left for #6
        // eoa3: fully claimed and redeemed #2.

        // Disable rUSD minting
        creditEnforcer.setPSMDebtMax(0);

        //! Check that rUSD minting is disabled
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa3, 1_000_000e6);
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa2);
        creditEnforcer.mintStablecoin(eoa3, 1e6);
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa3);
        creditEnforcer.mintStablecoin(eoa3, 1_000_000_000_000e6);

        // Set Term Debt Max for future brUSD's to 0
        for (
            uint256 i = termIssuer.earliestID();
            i <= termIssuer.latestID() + 20;
            i++
        ) {
            creditEnforcer.setTermDebtMax(i, 0);
        }

        vm.prank(eoa1);
        rusd.approve(address(accountManager), type(uint256).max);
        vm.prank(eoa2);
        rusd.approve(address(accountManager), type(uint256).max);
        vm.prank(eoa3);
        rusd.approve(address(accountManager), type(uint256).max);

        //! Check that brUSD minting is disabled
        for (
            uint256 i = termIssuer.earliestID();
            i <= termIssuer.latestID();
            i++
        ) {
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa1);
            accountManager.mintTerm(i, 1);
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa2);
            accountManager.mintTerm(i, 1);
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa3);
            accountManager.mintTerm(i, 1);
        }

        //! Make sure users are able to redeem their rUSD
        vm.prank(eoa1);
        rusd.approve(address(psm), 100_000e18);
        vm.prank(eoa1);
        psm.redeem(100_000e6);
        vm.prank(eoa2);
        rusd.approve(address(psm), 1e18);
        vm.prank(eoa2);
        psm.redeem(1e6);
        vm.prank(eoa3);
        rusd.approve(address(psm), 10_000_000e18);
        vm.prank(eoa3);
        psm.redeem(10_000_000e6);

        //! Make sure users are able to claim their brUSD coupons
        _claimCoupon(eoa1, 5);
        _claimCoupon(eoa2, 6);
        _claimCoupon(eoa2, 2);
        skip(DELTA);
        _claimCoupon(eoa1, 5);
        _claimCoupon(eoa2, 6);
        skip(DELTA);
        _claimCoupon(eoa1, 5);
        _claimCoupon(eoa2, 6);
        skip(DELTA);
        _claimCoupon(eoa2, 6);

        //! Make sure users are able to redeem their brUSD
        _redeemBond(eoa1, 5);
        _redeemBond(eoa2, 6);
        _redeemBond(eoa2, 2);

        //! Make sure users are able to redeem their full rUSD
        uint256 rusdBalanceEoa1 = rusd.balanceOf(eoa1);
        vm.prank(eoa1);
        rusd.approve(address(psm), rusdBalanceEoa1);
        vm.prank(eoa1);
        psm.redeem(rusdBalanceEoa1 / 1e12);
        uint256 rusdBalanceEoa2 = rusd.balanceOf(eoa2);
        vm.prank(eoa2);
        rusd.approve(address(psm), rusdBalanceEoa2);
        vm.prank(eoa2);
        psm.redeem(rusdBalanceEoa2 / 1e12);
        uint256 rusdBalanceEoa3 = rusd.balanceOf(eoa3);
        vm.prank(eoa3);
        rusd.approve(address(psm), rusdBalanceEoa3);
        vm.prank(eoa3);
        psm.redeem(rusdBalanceEoa3 / 1e12);

        for (uint256 i = 1; i <= 20; i++) {
            assertEq(term.totalSupply(i), 0);
        }
        assertEq(termIssuer.totalDebt(), 0);

        //! Check that brUSD minting is disabled AFTER checking that every brUSD supply is 0
        for (
            uint256 i = termIssuer.earliestID();
            i <= termIssuer.latestID();
            i++
        ) {
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa1);
            accountManager.mintTerm(i, 1);
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa2);
            accountManager.mintTerm(i, 1);
            vm.expectRevert("CE: amount exceeds term minter debt max");
            vm.prank(eoa3);
            accountManager.mintTerm(i, 1);
        }

        //! Check that rUSD minting is disabled
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa3, 1_000_000e6);
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa2);
        creditEnforcer.mintStablecoin(eoa3, 1e6);
        vm.expectRevert("CE: amount exceeds PSM debt max");
        vm.prank(eoa3);
        creditEnforcer.mintStablecoin(eoa3, 1_000_000_000_000e6);
    }
}
