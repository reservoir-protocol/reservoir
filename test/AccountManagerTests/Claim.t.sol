// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerClaimTest is AccountManagerFuzzTest {
    event ClaimCoupon(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 amount,
        uint256 timestamp
    );

    function testFirstClaim(
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

        uint256 rusdAfterMinting = rusd.balanceOf(address(this));
        uint256 couponValue = accountManager
            .getUserPosition(address(this), termId)
            .coupons[0];
        uint256 couponCount = accountManager
            .getUserPosition(address(this), termId)
            .coupons
            .length;

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        skip(DELTA);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertTrue(canClaim);
        }

        uint256 firstTermAmountBeforeClaiming = term.balanceOf(
            address(accountManager),
            1
        );

        accountManager.claim(termId);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            couponCount - 1
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            couponCount - 1
        );
        assertEq(
            accountManager.getCoupons(address(this), termId).length,
            couponCount - 1
        );
        assertEq(rusd.balanceOf(address(this)), rusdAfterMinting + couponValue);
        assertEq(
            term.balanceOf(address(accountManager), 1),
            firstTermAmountBeforeClaiming - couponValue
        );
    }

    function testFirstClaimWithTo(
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

        uint256 rusdAfterMinting = rusd.balanceOf(address(this));
        uint256 couponValue = accountManager
            .getUserPosition(address(this), termId)
            .coupons[0];
        uint256 couponCount = accountManager
            .getUserPosition(address(this), termId)
            .coupons
            .length;

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        skip(DELTA);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertTrue(canClaim);
        }

        uint256 firstTermAmountBeforeClaiming = term.balanceOf(
            address(accountManager),
            1
        );

        accountManager.claim(to, termId);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            couponCount - 1
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            couponCount - 1
        );
        assertEq(
            accountManager.getCoupons(address(this), termId).length,
            couponCount - 1
        );
        assertEq(rusd.balanceOf(address(this)), rusdAfterMinting);
        assertEq(rusd.balanceOf(to), couponValue);
        assertEq(
            term.balanceOf(address(accountManager), 1),
            firstTermAmountBeforeClaiming - couponValue
        );
    }

    function testAllClaims(
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

        uint256 rusdAfterMinting = rusd.balanceOf(address(this));
        uint256 couponValue = accountManager
            .getUserPosition(address(this), termId)
            .coupons[0];
        uint256 couponCount = accountManager
            .getUserPosition(address(this), termId)
            .coupons
            .length;

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        skip(DELTA * termId);

        uint256 termAmountBeforeClaiming = term.balanceOf(
            address(accountManager),
            termId
        );

        for (uint8 i = 0; i < couponCount; i++) {
            {
                (bool canClaim, ) = accountManager.canClaim(
                    address(this),
                    termId
                );
                assertTrue(canClaim);
            }
            vm.expectEmit(true, true, true, true);
            emit ClaimCoupon(
                address(this),
                address(this),
                termId,
                accountManager.getUserPosition(address(this), termId).coupons[
                    0
                ],
                block.timestamp
            );
            accountManager.claim(termId);
        }

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        assertEq(
            accountManager
                .getUserPosition(address(this), termId)
                .coupons
                .length,
            0
        );
        assertEq(
            accountManager.getCurrentHoldings(address(this))[0].coupons.length,
            0
        );
        assertEq(accountManager.getCoupons(address(this), termId).length, 0);
        assertEq(
            rusd.balanceOf(address(this)),
            rusdAfterMinting + (couponValue * couponCount)
        );

        for (uint8 i = 1; i <= termId; i++) {
            if (i == termId) {
                assertEq(
                    term.balanceOf(address(accountManager), i),
                    termAmountBeforeClaiming - couponValue
                );
            } else {
                assertEq(term.balanceOf(address(accountManager), i), 0);
            }
        }
    }

    function testClaimBeforeCouponMaturity(
        uint128 amount,
        uint32 termDiscountRate,
        uint64 couponRate,
        uint8 termId,
        uint256 timeBeforeMaturity
    ) external {
        vm.assume(amount < BILLION_18_DECIMALS);
        vm.assume(termId > 0 && termId < 6);
        vm.assume(timeBeforeMaturity > 1 && timeBeforeMaturity <= DELTA);
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

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        skip(DELTA - timeBeforeMaturity);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        vm.expectRevert("AM: no coupon available");
        accountManager.claim(termId);
    }

    function testClaimUnownedTerm(uint8 termId) external {
        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        vm.expectRevert("AM: no coupon available");
        accountManager.claim(termId);
    }

    function testClaimRedeemedTerm(
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

        uint256 couponCount = accountManager
            .getUserPosition(address(this), termId)
            .coupons
            .length;

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        skip(DELTA * termId);

        for (uint8 i = 0; i < couponCount; i++) {
            {
                (bool canClaim, ) = accountManager.canClaim(
                    address(this),
                    termId
                );
                assertTrue(canClaim);
            }
            accountManager.claim(termId);
        }

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        accountManager.redeem(termId);

        {
            (bool canClaim, ) = accountManager.canClaim(address(this), termId);
            assertFalse(canClaim);
        }

        vm.expectRevert("AM: no coupon available");
        accountManager.claim(termId);
    }
}
