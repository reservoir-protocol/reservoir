// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerRedeemTest is AccountManagerFuzzTest {
    function testRedeemTheOnlyBond(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId
    ) external {
        vm.assume(amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(couponRate < 1e12);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost, ) = accountManager.getQuote(termId, amount);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost);
        usdc.approve(address(psm), cost);
        creditEnforcer.mintStablecoin(cost);

        rusd.approve(address(accountManager), cost);

        accountManager.mintTerm(termId, amount);

        skip(DELTA * termId);

        for (uint8 i = 0; i < termId; i++) {
            accountManager.claim(termId);
        }

        uint256 rusdBalanceBeforeRedeem = rusd.balanceOf(address(this));

        accountManager.redeem(termId);

        assertEq(accountManager.getAccountList(address(this)).length, 0);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 0);
        assertEq(accountManager.getCoupons(address(this), termId).length, 0);
        assertEq(
            accountManager.getUserPosition(address(this), termId).principle,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            0
        );

        assertEq(
            rusd.balanceOf(address(this)),
            rusdBalanceBeforeRedeem + amount
        );
    }

    function testRedeemTheOnlyBondWithTo(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId,
        address to
    ) external {
        vm.assume(amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(
            to != address(0) &&
                to != address(this) &&
                to != address(accountManager)
        );
        vm.assume(couponRate < 1e12);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost, ) = accountManager.getQuote(termId, amount);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost);
        usdc.approve(address(psm), cost);
        creditEnforcer.mintStablecoin(cost);

        rusd.approve(address(accountManager), cost);

        accountManager.mintTerm(termId, amount);

        skip(DELTA * termId);

        for (uint8 i = 0; i < termId; i++) {
            accountManager.claim(termId);
        }

        uint256 rusdBalanceBeforeRedeem = rusd.balanceOf(address(this));

        accountManager.redeem(to, termId);

        assertEq(accountManager.getAccountList(address(this)).length, 0);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 0);
        assertEq(accountManager.getCoupons(address(this), termId).length, 0);
        assertEq(
            accountManager.getUserPosition(address(this), termId).principle,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            0
        );

        assertEq(rusd.balanceOf(address(this)), rusdBalanceBeforeRedeem);
        assertEq(rusd.balanceOf(to), amount);
    }

    function testRedeemFirstFromTwoBonds(
        uint128 amount1,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId1
    ) external {
        vm.assume(amount1 < BILLION_18_DECIMALS);
        vm.assume(termId1 > 1 && termId1 < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount2 = amount1 / 2;
        uint256 termId2 = termId1 / 2;

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost1, ) = accountManager.getQuote(termId1, amount1);
        (uint256 cost2, ) = accountManager.getQuote(termId2, amount2);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost1 + cost2);
        usdc.approve(address(psm), cost1 + cost2);
        creditEnforcer.mintStablecoin(cost1 + cost2);

        rusd.approve(address(accountManager), cost1 + cost2);

        accountManager.mintTerm(termId1, amount1);
        accountManager.mintTerm(termId2, amount2);

        skip(DELTA * termId1);

        for (uint8 i = 0; i < termId1; i++) {
            accountManager.claim(termId1);
            if (i < termId2) accountManager.claim(termId2);
        }

        uint256 rusdBalanceBeforeRedeem = rusd.balanceOf(address(this));

        accountManager.redeem(termId1);

        assertEq(accountManager.getAccountList(address(this)).length, 1);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 1);

        assertEq(accountManager.getAccountList(address(this))[0], termId2);
        assertEq(
            accountManager.getUserPosition(address(this), termId2).principle,
            amount2
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId2).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId2)
                .coupons
                .length,
            0
        );
        assertEq(accountManager.getCoupons(address(this), termId2).length, 0);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount2
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            0
        );

        assertEq(
            accountManager.getUserPosition(address(this), termId1).principle,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId1).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId1)
                .coupons
                .length,
            0
        );
        assertEq(accountManager.getCoupons(address(this), termId1).length, 0);

        assertEq(
            rusd.balanceOf(address(this)),
            rusdBalanceBeforeRedeem + amount1
        );
    }

    function testRedeemSecondFromTwoBonds(
        uint128 amount1,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId1
    ) external {
        vm.assume(amount1 < BILLION_18_DECIMALS);
        vm.assume(termId1 > 1 && termId1 < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount2 = amount1 / 2;
        uint256 termId2 = termId1 / 2;

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost1, ) = accountManager.getQuote(termId1, amount1);
        (uint256 cost2, ) = accountManager.getQuote(termId2, amount2);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost1 + cost2);
        usdc.approve(address(psm), cost1 + cost2);
        creditEnforcer.mintStablecoin(cost1 + cost2);

        rusd.approve(address(accountManager), cost1 + cost2);

        accountManager.mintTerm(termId1, amount1);
        accountManager.mintTerm(termId2, amount2);

        skip(DELTA * termId1);

        for (uint8 i = 0; i < termId1; i++) {
            accountManager.claim(termId1);
            if (i < termId2) accountManager.claim(termId2);
        }

        uint256 rusdBalanceBeforeRedeem = rusd.balanceOf(address(this));

        accountManager.redeem(termId2);

        assertEq(accountManager.getAccountList(address(this)).length, 1);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 1);

        assertEq(accountManager.getAccountList(address(this))[0], termId1);
        assertEq(
            accountManager.getUserPosition(address(this), termId1).principle,
            amount1
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId1).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId1)
                .coupons
                .length,
            0
        );
        assertEq(accountManager.getCoupons(address(this), termId1).length, 0);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount1
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            0
        );

        assertEq(
            accountManager.getUserPosition(address(this), termId2).principle,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId2).index,
            0
        );
        assertEq(
            accountManager
                .getUserPosition(address(this), termId2)
                .coupons
                .length,
            0
        );
        assertEq(accountManager.getCoupons(address(this), termId2).length, 0);

        assertEq(
            rusd.balanceOf(address(this)),
            rusdBalanceBeforeRedeem + amount2
        );
    }

    function testRedeemAllBondsOneByOne(
        uint128 amount1,
        uint32 termDiscountRate,
        uint64 couponRate
    ) external {
        vm.assume(amount1 < BILLION_18_DECIMALS);
        vm.assume(couponRate < 1e12);

        uint256 amount2 = amount1 / 2;
        uint256 amount3 = amount1 / 3;
        uint256 amount4 = amount1 / 4;
        uint256 amount5 = amount1 / 5;

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost1, ) = accountManager.getQuote(1, amount1);
        (uint256 cost2, ) = accountManager.getQuote(2, amount2);
        (uint256 cost3, ) = accountManager.getQuote(3, amount3);
        (uint256 cost4, ) = accountManager.getQuote(4, amount4);
        (uint256 cost5, ) = accountManager.getQuote(5, amount5);

        uint256 totalCost = cost1 + cost2 + cost3 + cost4 + cost5;

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), totalCost);
        usdc.approve(address(psm), totalCost);
        creditEnforcer.mintStablecoin(totalCost);

        rusd.approve(address(accountManager), totalCost);

        accountManager.mintTerm(1, amount1);
        accountManager.mintTerm(2, amount2);
        accountManager.mintTerm(3, amount3);
        accountManager.mintTerm(4, amount4);
        accountManager.mintTerm(5, amount5);

        skip(DELTA * 5);

        accountManager.claim(1);
        accountManager.claim(2);
        accountManager.claim(2);
        accountManager.claim(3);
        accountManager.claim(3);
        accountManager.claim(3);
        accountManager.claim(4);
        accountManager.claim(4);
        accountManager.claim(4);
        accountManager.claim(4);
        accountManager.claim(5);
        accountManager.claim(5);
        accountManager.claim(5);
        accountManager.claim(5);
        accountManager.claim(5);

        accountManager.redeem(2);

        assertEq(accountManager.getAccountList(address(this)).length, 4);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 4);

        assertEq(accountManager.getAccountList(address(this))[0], 1);
        assertEq(accountManager.getAccountList(address(this))[1], 5);
        assertEq(accountManager.getAccountList(address(this))[2], 3);
        assertEq(accountManager.getAccountList(address(this))[3], 4);

        assertEq(
            accountManager.getUserPosition(address(this), 1).principle,
            amount1
        );
        assertEq(accountManager.getUserPosition(address(this), 2).principle, 0);
        assertEq(
            accountManager.getUserPosition(address(this), 3).principle,
            amount3
        );
        assertEq(
            accountManager.getUserPosition(address(this), 4).principle,
            amount4
        );
        assertEq(
            accountManager.getUserPosition(address(this), 5).principle,
            amount5
        );

        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount1
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[1].principle,
            amount5
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[2].principle,
            amount3
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[3].principle,
            amount4
        );

        assertEq(accountManager.getUserPosition(address(this), 1).index, 0);
        assertEq(accountManager.getUserPosition(address(this), 3).index, 2);
        assertEq(accountManager.getUserPosition(address(this), 4).index, 3);
        assertEq(accountManager.getUserPosition(address(this), 5).index, 1);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(address(this))[1].index, 1);
        assertEq(accountManager.getCurrentHoldings(address(this))[2].index, 2);
        assertEq(accountManager.getCurrentHoldings(address(this))[3].index, 3);

        accountManager.redeem(1);

        assertEq(accountManager.getAccountList(address(this)).length, 3);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 3);

        assertEq(accountManager.getAccountList(address(this))[0], 4);
        assertEq(accountManager.getAccountList(address(this))[1], 5);
        assertEq(accountManager.getAccountList(address(this))[2], 3);

        assertEq(accountManager.getUserPosition(address(this), 1).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 2).principle, 0);
        assertEq(
            accountManager.getUserPosition(address(this), 3).principle,
            amount3
        );
        assertEq(
            accountManager.getUserPosition(address(this), 4).principle,
            amount4
        );
        assertEq(
            accountManager.getUserPosition(address(this), 5).principle,
            amount5
        );

        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount4
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[1].principle,
            amount5
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[2].principle,
            amount3
        );

        assertEq(accountManager.getUserPosition(address(this), 3).index, 2);
        assertEq(accountManager.getUserPosition(address(this), 4).index, 0);
        assertEq(accountManager.getUserPosition(address(this), 5).index, 1);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(address(this))[1].index, 1);
        assertEq(accountManager.getCurrentHoldings(address(this))[2].index, 2);

        accountManager.redeem(3);

        assertEq(accountManager.getAccountList(address(this)).length, 2);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 2);

        assertEq(accountManager.getAccountList(address(this))[0], 4);
        assertEq(accountManager.getAccountList(address(this))[1], 5);

        assertEq(accountManager.getUserPosition(address(this), 1).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 2).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 3).principle, 0);
        assertEq(
            accountManager.getUserPosition(address(this), 4).principle,
            amount4
        );
        assertEq(
            accountManager.getUserPosition(address(this), 5).principle,
            amount5
        );

        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount4
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[1].principle,
            amount5
        );

        assertEq(accountManager.getUserPosition(address(this), 4).index, 0);
        assertEq(accountManager.getUserPosition(address(this), 5).index, 1);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(address(this))[1].index, 1);

        accountManager.redeem(4);

        assertEq(accountManager.getAccountList(address(this)).length, 1);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 1);

        assertEq(accountManager.getAccountList(address(this))[0], 5);

        assertEq(accountManager.getUserPosition(address(this), 1).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 2).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 3).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 4).principle, 0);
        assertEq(
            accountManager.getUserPosition(address(this), 5).principle,
            amount5
        );

        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount5
        );

        assertEq(accountManager.getUserPosition(address(this), 5).index, 0);

        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);

        accountManager.redeem(5);

        assertEq(accountManager.getAccountList(address(this)).length, 0);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 0);

        assertEq(accountManager.getUserPosition(address(this), 1).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 2).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 3).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 4).principle, 0);
        assertEq(accountManager.getUserPosition(address(this), 5).principle, 0);
    }

    function testRedeemNotFullyClaimedBond(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId
    ) external {
        vm.assume(amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(couponRate < 1e12);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost, ) = accountManager.getQuote(termId, amount);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost);
        usdc.approve(address(psm), cost);
        creditEnforcer.mintStablecoin(cost);

        rusd.approve(address(accountManager), cost);

        accountManager.mintTerm(termId, amount);

        skip(DELTA * termId);

        for (uint8 i = 0; i < termId - 1; i++) {
            accountManager.claim(termId);
        }

        vm.expectRevert("AM: all coupons must be claimed");
        accountManager.redeem(termId);
    }
}
