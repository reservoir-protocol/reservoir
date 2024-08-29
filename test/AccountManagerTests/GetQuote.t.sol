// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerGetQuoteTest is AccountManagerFuzzTest {
    uint256 couponCount;
    uint256 couponValue;

    function testGetQuote(
        uint256 amount,
        uint32 discountRate,
        uint64 couponRate,
        uint8 earliestId,
        uint8 termId
    ) external {
        vm.assume(amount < BILLION_18_DECIMALS);
        vm.assume(earliestId > 0);
        vm.assume(termId >= earliestId && termId < uint256(earliestId) + 5);
        vm.assume(couponRate < 1e12);

        skip(DELTA * (earliestId - 1));

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        for (uint256 i = earliestId; i < uint256(earliestId) + 5; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);
            termIssuer.setDiscountRate(i, discountRate);
        }

        (uint256 cost, uint256 profit) = accountManager.getQuote(
            termId,
            amount
        );

        uint256 earliestID = termIssuer.earliestID();
        couponCount = termId >= earliestID
            ? termId - uint256(earliestId) + 1
            : 0;
        couponValue = (couponRate * amount) / (4 * 1e12);

        uint256 expectedCost;
        uint256 expectedProfit = amount;

        for (uint256 i = 0; i < couponCount; i++) {
            expectedProfit += couponValue;
            expectedCost += termIssuer.applyDiscount(
                couponValue,
                termIssuer.maturityTimestamp(termId - i),
                termIssuer.getDiscountRate(termId - i)
            );
        }

        expectedCost += termIssuer.applyDiscount(
            amount,
            termIssuer.maturityTimestamp(termId),
            termIssuer.getDiscountRate(termId)
        );
        expectedProfit -= expectedCost;

        assertEq(profit, expectedProfit);
        assertEq(cost, expectedCost);

        for (uint256 i = 6; i < 20; i++) {
            (uint256 _cost, uint256 _profit) = accountManager.getQuote(
                earliestId + i,
                amount
            );
            assertEq(_cost, type(uint256).max);
            assertEq(_profit, 0);
        }

        for (uint256 i = 1; i < earliestId; i++) {
            (uint256 _cost, uint256 _profit) = accountManager.getQuote(
                i,
                amount
            );
            assertEq(_cost, type(uint256).max);
            assertEq(_profit, 0);
        }
    }
}
