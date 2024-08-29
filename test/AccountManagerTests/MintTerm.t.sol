// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerMintTermTest is AccountManagerFuzzTest {
    function testMintTermOnce(
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

        uint256 walletsInitialrusd = rusd.balanceOf(address(this));

        accountManager.mintTerm(termId, amount);

        // Check AM State
        assertEq(accountManager.accountListLength(address(this)), 1);
        assertEq(accountManager.getAccountList(address(this))[0], termId);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 1);
        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).index,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).principle,
            amount
        );
        uint256 couponCount = termId - termIssuer.earliestID() + 1;
        uint256 couponValue = (uint256(couponRate) * uint256(amount)) /
            (4 * 1e12);

        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            couponCount
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            couponCount
        );
        assertEq(
            accountManager.getCoupons(address(this), termId).length,
            couponCount
        );
        for (uint256 i; i < couponCount; i++) {
            assertEq(
                accountManager.getUserPosition(address(this), termId).coupons[
                    i
                ],
                couponValue
            );
            assertEq(
                accountManager.getCurrentHoldings(address(this))[0].coupons[i],
                couponValue
            );
            uint256 ci = termId - i; // couponId
            assertEq(
                accountManager.getCoupons(address(this), termId)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);
        assertEq(rusd.balanceOf(address(this)), walletsInitialrusd - cost);

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId; i++) {
            if (i == termId) {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    amount + couponValue
                );
            } else {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    couponValue
                );
            }
        }
    }

    function testMintTermOnceWithTo(
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

        uint256 walletsInitialrusd = rusd.balanceOf(address(this));

        accountManager.mintTerm(to, termId, amount);

        // Check AM State
        assertEq(accountManager.accountListLength(address(this)), 0);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 0);
        assertEq(
            accountManager.getUserPosition(address(this), termId).principle,
            0
        );

        assertEq(accountManager.accountListLength(to), 1);
        assertEq(accountManager.getAccountList(to)[0], termId);
        assertEq(accountManager.getCurrentHoldings(to).length, 1);
        assertEq(accountManager.getCurrentHoldings(to)[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(to)[0].principle, amount);
        assertEq(accountManager.getUserPosition(to, termId).index, 0);
        assertEq(accountManager.getUserPosition(to, termId).principle, amount);

        uint256 couponCount = termId - termIssuer.earliestID() + 1;
        uint256 couponValue = (uint256(couponRate) * uint256(amount)) /
            (4 * 1e12);

        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            0
        );
        assertEq(
            accountManager.getUserPosition(to, termId).coupons.length,
            couponCount
        );
        assertEq(
            accountManager.getCurrentHoldings(to)[0].coupons.length,
            couponCount
        );
        assertEq(accountManager.getCoupons(to, termId).length, couponCount);
        assertEq(accountManager.getCoupons(address(this), termId).length, 0);

        for (uint256 i; i < couponCount; i++) {
            assertEq(
                accountManager.getUserPosition(to, termId).coupons[i],
                couponValue
            );
            assertEq(
                accountManager.getCurrentHoldings(to)[0].coupons[i],
                couponValue
            );
            uint256 ci = termId - i; // couponId
            assertEq(
                accountManager.getCoupons(to, termId)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager.getCoupons(to, termId)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager.getCoupons(to, termId)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);
        assertEq(rusd.balanceOf(to), 0);
        assertEq(rusd.balanceOf(address(this)), walletsInitialrusd - cost);

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId; i++) {
            if (i == termId) {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    amount + couponValue
                );
            } else {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    couponValue
                );
            }
        }
    }

    function testMintSameTermTwice(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId
    ) external {
        vm.assume(amount > 1e18 && amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount1 = amount;
        uint256 amount2 = amount1 / 2;

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost1, ) = accountManager.getQuote(termId, amount1);
        (uint256 cost2, ) = accountManager.getQuote(termId, amount2);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(address(this), cost1 + cost2);
        usdc.approve(address(psm), cost1 + cost2);
        creditEnforcer.mintStablecoin(cost1 + cost2);

        rusd.approve(address(accountManager), cost1 + cost2);

        uint256 walletsInitialrusd = rusd.balanceOf(address(this));

        accountManager.mintTerm(termId, amount1);
        accountManager.mintTerm(termId, amount2);

        // // Check AM State
        assertEq(accountManager.accountListLength(address(this)), 1);
        assertEq(accountManager.getAccountList(address(this))[0], termId);
        assertEq(accountManager.getCurrentHoldings(address(this)).length, 1);
        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount1 + amount2
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).index,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId).principle,
            amount1 + amount2
        );
        uint256 couponCount = termId - termIssuer.earliestID() + 1;
        uint256 couponValue = (couponRate * amount1) /
            (4 * 1e12) +
            (couponRate * amount2) /
            (4 * 1e12);
        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            couponCount
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            couponCount
        );
        assertEq(
            accountManager.getCoupons(address(this), termId).length,
            couponCount
        );
        for (uint256 i; i < couponCount; i++) {
            assertEq(
                accountManager.getUserPosition(address(this), termId).coupons[
                    i
                ],
                couponValue
            );
            assertEq(
                accountManager.getCurrentHoldings(address(this))[0].coupons[i],
                couponValue
            );
            uint256 ci = termId - i; // couponId
            assertEq(
                accountManager.getCoupons(address(this), termId)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);
        assertEq(
            rusd.balanceOf(address(this)),
            walletsInitialrusd - cost1 - cost2
        );

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId; i++) {
            if (i == termId) {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    amount1 + amount2 + couponValue
                );
            } else {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    couponValue
                );
            }
        }
    }

    function testMintDifferentTerms(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId1
    ) external {
        vm.assume(amount > 1e18 && amount < BILLION_18_DECIMALS);
        vm.assume(termId1 > 1 && termId1 < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount1 = amount;
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

        uint256 walletsInitialrusd = rusd.balanceOf(address(this));

        accountManager.mintTerm(termId1, amount1);
        accountManager.mintTerm(termId2, amount2);

        // Check AM State
        assertEq(accountManager.accountListLength(address(this)), 2);
        assertEq(accountManager.getAccountList(address(this))[0], termId1);
        assertEq(accountManager.getAccountList(address(this))[1], termId2);

        assertEq(accountManager.getCurrentHoldings(address(this)).length, 2);
        assertEq(accountManager.getCurrentHoldings(address(this))[0].index, 0);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].principle,
            amount1
        );
        assertEq(accountManager.getCurrentHoldings(address(this))[1].index, 1);
        assertEq(
            accountManager.getCurrentHoldings(address(this))[1].principle,
            amount2
        );

        assertEq(
            accountManager.getUserPosition(address(this), termId1).index,
            0
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId1).principle,
            amount1
        );
        uint256 couponCount1 = termId1 - termIssuer.earliestID() + 1;
        uint256 couponValue1 = (couponRate * amount1) / (4 * 1e12);
        assertEq(
            accountManager
                .getUserPosition(address(this), termId1)
                .coupons
                .length,
            couponCount1
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            couponCount1
        );
        assertEq(
            accountManager.getCoupons(address(this), termId1).length,
            couponCount1
        );
        for (uint256 i; i < couponCount1; i++) {
            assertEq(
                accountManager.getUserPosition(address(this), termId1).coupons[
                    i
                ],
                couponValue1
            );
            assertEq(
                accountManager.getCurrentHoldings(address(this))[0].coupons[i],
                couponValue1
            );
            uint256 ci = termId1 - i; // couponId
            assertEq(
                accountManager.getCoupons(address(this), termId1)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId1)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId1)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        assertEq(
            accountManager.getUserPosition(address(this), termId2).index,
            1
        );
        assertEq(
            accountManager.getUserPosition(address(this), termId2).principle,
            amount2
        );
        uint256 couponCount2 = termId2 - termIssuer.earliestID() + 1;
        uint256 couponValue2 = (couponRate * amount2) / (4 * 1e12);
        assertEq(
            accountManager
                .getUserPosition(address(this), termId2)
                .coupons
                .length,
            couponCount2
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[1].coupons.length,
            couponCount2
        );
        assertEq(
            accountManager.getCoupons(address(this), termId2).length,
            couponCount2
        );
        for (uint256 i; i < couponCount2; i++) {
            assertEq(
                accountManager.getUserPosition(address(this), termId2).coupons[
                    i
                ],
                couponValue2
            );
            assertEq(
                accountManager.getCurrentHoldings(address(this))[1].coupons[i],
                couponValue2
            );
            uint256 ci = termId2 - i; // couponId
            assertEq(
                accountManager.getCoupons(address(this), termId2)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId2)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager
                .getCoupons(address(this), termId2)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);
        assertEq(
            rusd.balanceOf(address(this)),
            walletsInitialrusd - cost1 - cost2
        );

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId1; i++) {
            uint256 value1;
            uint256 value2;

            if (i < termId1) value1 = couponValue1;
            if (i == termId1) value1 = amount1 + couponValue1;

            if (i < termId2) value2 = couponValue2;
            if (i == termId2) value2 = amount2 + couponValue2;

            assertEq(
                term.balanceOf(address(accountManager), i),
                value1 + value2
            );
        }
    }

    function testMintSameTermsFrom2Wallets(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId
    ) external {
        vm.assume(amount > 1e18 && amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount1 = amount;
        uint256 amount2 = amount1 / 2;

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i; i < 6; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, termDiscountRate);
        }

        (uint256 cost1, ) = accountManager.getQuote(termId, amount1);
        (uint256 cost2, ) = accountManager.getQuote(termId, amount2);

        // This is not minting exact amount of usdc for exact amount of rusd cost
        // Because cost is 18 decimals and in mintStablecoin we pass 6 decimals
        usdc.mint(eoa1, cost1);
        usdc.mint(eoa2, cost2);

        vm.prank(eoa1);
        usdc.approve(address(psm), cost1);
        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(cost1);

        vm.prank(eoa2);
        usdc.approve(address(psm), cost2);
        vm.prank(eoa2);
        creditEnforcer.mintStablecoin(cost2);

        vm.prank(eoa1);
        rusd.approve(address(accountManager), cost1);

        vm.prank(eoa2);
        rusd.approve(address(accountManager), cost2);

        uint256 wallet1sInitialrusd = rusd.balanceOf(eoa1);
        uint256 wallet2sInitialrusd = rusd.balanceOf(eoa2);

        vm.prank(eoa1);
        accountManager.mintTerm(termId, amount1);
        vm.prank(eoa2);
        accountManager.mintTerm(termId, amount2);

        // Check AM State
        assertEq(accountManager.accountListLength(eoa1), 1);
        assertEq(accountManager.getAccountList(eoa1)[0], termId);
        assertEq(accountManager.getCurrentHoldings(eoa1).length, 1);
        assertEq(accountManager.getCurrentHoldings(eoa1)[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(eoa1)[0].principle, amount1);
        assertEq(accountManager.getUserPosition(eoa1, termId).index, 0);
        assertEq(
            accountManager.getUserPosition(eoa1, termId).principle,
            amount1
        );

        assertEq(accountManager.accountListLength(eoa2), 1);
        assertEq(accountManager.getAccountList(eoa2)[0], termId);
        assertEq(accountManager.getCurrentHoldings(eoa2).length, 1);
        assertEq(accountManager.getCurrentHoldings(eoa2)[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(eoa2)[0].principle, amount2);
        assertEq(accountManager.getUserPosition(eoa2, termId).index, 0);
        assertEq(
            accountManager.getUserPosition(eoa2, termId).principle,
            amount2
        );

        uint256 couponCount = termId - termIssuer.earliestID() + 1;
        uint256 couponValue1 = (couponRate * amount1) / (4 * 1e12);
        uint256 couponValue2 = (couponRate * amount2) / (4 * 1e12);

        assertEq(
            accountManager.getUserPosition(eoa1, termId).coupons.length,
            couponCount
        );
        assertEq(
            accountManager.getCurrentHoldings(eoa1)[0].coupons.length,
            couponCount
        );
        assertEq(accountManager.getCoupons(eoa1, termId).length, couponCount);
        assertEq(
            accountManager.getUserPosition(eoa2, termId).coupons.length,
            couponCount
        );
        assertEq(
            accountManager.getCurrentHoldings(eoa2)[0].coupons.length,
            couponCount
        );
        assertEq(accountManager.getCoupons(eoa2, termId).length, couponCount);

        for (uint256 i; i < couponCount; i++) {
            assertEq(
                accountManager.getUserPosition(eoa1, termId).coupons[i],
                couponValue1
            );
            assertEq(
                accountManager.getCurrentHoldings(eoa1)[0].coupons[i],
                couponValue1
            );
            uint256 ci = termId - i; // couponId
            assertEq(
                accountManager.getCoupons(eoa1, termId)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager.getCoupons(eoa1, termId)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager.getCoupons(eoa1, termId)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
            assertEq(
                accountManager.getUserPosition(eoa2, termId).coupons[i],
                couponValue2
            );
            assertEq(
                accountManager.getCurrentHoldings(eoa2)[0].coupons[i],
                couponValue2
            );
            assertEq(
                accountManager.getCoupons(eoa2, termId)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager.getCoupons(eoa2, termId)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager.getCoupons(eoa2, termId)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);
        assertEq(rusd.balanceOf(eoa1), wallet1sInitialrusd - cost1);
        assertEq(rusd.balanceOf(eoa2), wallet2sInitialrusd - cost2);

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId; i++) {
            if (i == termId) {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    amount1 + amount2 + couponValue1 + couponValue2
                );
            } else {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    couponValue1 + couponValue2
                );
            }
        }
    }

    function testMintDifferentTermsFrom2Wallets(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId1
    ) external {
        vm.assume(amount > 1e18 && amount < BILLION_18_DECIMALS);
        vm.assume(termId1 > 1 && termId1 < 6);
        vm.assume(couponRate < 1e12);

        uint256 amount1 = amount;
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
        usdc.mint(eoa1, cost1);
        usdc.mint(eoa2, cost2);

        vm.prank(eoa1);
        usdc.approve(address(psm), cost1);
        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(cost1);

        vm.prank(eoa2);
        usdc.approve(address(psm), cost2);
        vm.prank(eoa2);
        creditEnforcer.mintStablecoin(cost2);

        vm.prank(eoa1);
        rusd.approve(address(accountManager), cost1);
        vm.prank(eoa2);
        rusd.approve(address(accountManager), cost2);

        // Avoiding stack too deep error
        {
            uint256 wallet1sInitialrusd = rusd.balanceOf(eoa1);
            uint256 wallet2sInitialrusd = rusd.balanceOf(eoa2);

            vm.prank(eoa1);
            accountManager.mintTerm(termId1, amount1);
            vm.prank(eoa2);
            accountManager.mintTerm(termId2, amount2);

            assertEq(rusd.balanceOf(eoa1), wallet1sInitialrusd - cost1);
            assertEq(rusd.balanceOf(eoa2), wallet2sInitialrusd - cost2);
        }

        // // Check AM State
        assertEq(accountManager.accountListLength(eoa1), 1);
        assertEq(accountManager.getAccountList(eoa1)[0], termId1);
        assertEq(accountManager.getCurrentHoldings(eoa1).length, 1);
        assertEq(accountManager.getCurrentHoldings(eoa1)[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(eoa1)[0].principle, amount1);
        assertEq(accountManager.getUserPosition(eoa1, termId1).index, 0);
        assertEq(
            accountManager.getUserPosition(eoa1, termId1).principle,
            amount1
        );

        assertEq(accountManager.accountListLength(eoa2), 1);
        assertEq(accountManager.getAccountList(eoa2)[0], termId2);
        assertEq(accountManager.getCurrentHoldings(eoa2).length, 1);
        assertEq(accountManager.getCurrentHoldings(eoa2)[0].index, 0);
        assertEq(accountManager.getCurrentHoldings(eoa2)[0].principle, amount2);
        assertEq(accountManager.getUserPosition(eoa2, termId2).index, 0);
        assertEq(
            accountManager.getUserPosition(eoa2, termId2).principle,
            amount2
        );

        uint256 couponCount1 = termId1 - termIssuer.earliestID() + 1;
        uint256 couponValue1 = (couponRate * amount1) / (4 * 1e12);
        uint256 couponCount2 = termId2 - termIssuer.earliestID() + 1;
        uint256 couponValue2 = (couponRate * amount2) / (4 * 1e12);

        assertEq(
            accountManager.getUserPosition(eoa1, termId1).coupons.length,
            couponCount1
        );
        assertEq(
            accountManager.getCurrentHoldings(eoa1)[0].coupons.length,
            couponCount1
        );
        assertEq(accountManager.getCoupons(eoa1, termId1).length, couponCount1);

        assertEq(
            accountManager.getUserPosition(eoa2, termId2).coupons.length,
            couponCount2
        );
        assertEq(
            accountManager.getCurrentHoldings(eoa2)[0].coupons.length,
            couponCount2
        );
        assertEq(accountManager.getCoupons(eoa2, termId2).length, couponCount2);

        for (uint256 i; i < couponCount1; i++) {
            assertEq(
                accountManager.getUserPosition(eoa1, termId1).coupons[i],
                couponValue1
            );
            assertEq(
                accountManager.getCurrentHoldings(eoa1)[0].coupons[i],
                couponValue1
            );
            uint256 ci = termId1 - i; // couponId
            assertEq(
                accountManager.getCoupons(eoa1, termId1)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager.getCoupons(eoa1, termId1)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager.getCoupons(eoa1, termId1)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }
        for (uint256 i; i < couponCount2; i++) {
            assertEq(
                accountManager.getUserPosition(eoa2, termId2).coupons[i],
                couponValue2
            );
            assertEq(
                accountManager.getCurrentHoldings(eoa2)[0].coupons[i],
                couponValue2
            );
            uint256 ci = termId2 - i; // couponId
            assertEq(
                accountManager.getCoupons(eoa2, termId2)[i].rate,
                accountManager.couponRate()
            );
            assertEq(
                accountManager.getCoupons(eoa2, termId2)[i].discountRate,
                termIssuer.getDiscountRate(ci)
            );
            assertEq(
                accountManager.getCoupons(eoa2, termId2)[i].claimTimestamp,
                accountManager.getMaturityTimestamp(ci)
            );
        }

        // Check that AM Correctly handles rusd
        assertEq(rusd.balanceOf(address(accountManager)), 0);

        // Check that AM Correctly gets the Term via dependency calls
        for (uint256 i = 1; i <= termId1; i++) {
            uint256 value1;
            uint256 value2;

            if (i < termId1) value1 = couponValue1;
            if (i == termId1) value1 = amount1 + couponValue1;

            if (i < termId2) value2 = couponValue2;
            if (i == termId2) value2 = amount2 + couponValue2;

            assertEq(
                term.balanceOf(address(accountManager), i),
                value1 + value2
            );
        }
    }
}
