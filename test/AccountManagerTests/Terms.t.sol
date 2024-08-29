// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerTermsTest is AccountManagerFuzzTest {
    uint256 termDiscountRate1;
    uint256 termDiscountRate2;
    uint256 termDiscountRate3;
    uint256 termDiscountRate4;
    uint256 termDiscountRate5;

    uint256 termId1;
    uint256 termId2;
    uint256 termId3;
    uint256 termId4;
    uint256 termId5;

    function testTerms(
        uint8 _termId,
        uint32 _termDiscountRate,
        uint64 _couponRate
    ) external {
        vm.assume(_termId > 0);
        vm.assume(_couponRate < 1e12);

        termDiscountRate1 = uint256(_termDiscountRate);
        termDiscountRate2 = termDiscountRate1 / 2;
        termDiscountRate3 = termDiscountRate1 / 3;
        termDiscountRate4 = termDiscountRate1 / 4;
        termDiscountRate5 = termDiscountRate1 / 5;

        termId1 = uint256(_termId);
        termId2 = termId1 + 1;
        termId3 = termId1 + 2;
        termId4 = termId1 + 3;
        termId5 = termId1 + 4;

        skip(DELTA * (_termId - 1));

        assertEq(accountManager.getCurrentId(), termId1);
        assertEq(accountManager.getLastId(), termId5);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            _couponRate
        );

        termIssuer.setDiscountRate(termId1, termDiscountRate1);
        termIssuer.setDiscountRate(termId2, termDiscountRate2);
        termIssuer.setDiscountRate(termId3, termDiscountRate3);
        termIssuer.setDiscountRate(termId4, termDiscountRate4);
        termIssuer.setDiscountRate(termId5, termDiscountRate5);

        AccountManager.TermToken[] memory termTokens = accountManager
            .getCurrentOffers();

        assertEq(termTokens[0].id, termId1);
        assertEq(
            termTokens[0].maturityTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[0].discountRate, termDiscountRate1);
        assertEq(termTokens[0].coupons.length, 1);
        assertEq(termTokens[0].coupons[0].rate, _couponRate);
        assertEq(
            termTokens[0].coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[0].coupons[0].discountRate, termDiscountRate1);
        assertEq(accountManager.getTerm(termId1).id, termId1);
        assertEq(
            accountManager.getTerm(termId1).maturityTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId1).discountRate,
            termDiscountRate1
        );
        assertEq(accountManager.getTerm(termId1).coupons.length, 1);
        assertEq(accountManager.getTerm(termId1).coupons[0].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId1).coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId1).coupons[0].discountRate,
            termDiscountRate1
        );

        assertEq(termTokens[1].id, termId2);
        assertEq(
            termTokens[1].maturityTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(termTokens[1].discountRate, termDiscountRate2);
        assertEq(termTokens[1].coupons.length, 2);
        assertEq(termTokens[1].coupons[0].rate, _couponRate);
        assertEq(
            termTokens[1].coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(termTokens[1].coupons[0].discountRate, termDiscountRate2);
        assertEq(termTokens[1].coupons[1].rate, _couponRate);
        assertEq(
            termTokens[1].coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[1].coupons[1].discountRate, termDiscountRate1);
        assertEq(accountManager.getTerm(termId2).id, termId2);
        assertEq(
            accountManager.getTerm(termId2).maturityTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(
            accountManager.getTerm(termId2).discountRate,
            termDiscountRate2
        );
        assertEq(accountManager.getTerm(termId2).coupons.length, 2);
        assertEq(accountManager.getTerm(termId2).coupons[0].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId2).coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(
            accountManager.getTerm(termId2).coupons[0].discountRate,
            termDiscountRate2
        );
        assertEq(accountManager.getTerm(termId2).coupons[1].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId2).coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId2).coupons[1].discountRate,
            termDiscountRate1
        );

        assertEq(termTokens[2].id, termId3);
        assertEq(
            termTokens[2].maturityTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(termTokens[2].discountRate, termDiscountRate3);
        assertEq(termTokens[2].coupons.length, 3);
        assertEq(termTokens[2].coupons[0].rate, _couponRate);
        assertEq(
            termTokens[2].coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(termTokens[2].coupons[0].discountRate, termDiscountRate3);
        assertEq(termTokens[2].coupons[1].rate, _couponRate);
        assertEq(
            termTokens[2].coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(termTokens[2].coupons[1].discountRate, termDiscountRate2);
        assertEq(termTokens[2].coupons[2].rate, _couponRate);
        assertEq(
            termTokens[2].coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[2].coupons[2].discountRate, termDiscountRate1);
        assertEq(accountManager.getTerm(termId3).id, termId3);
        assertEq(
            accountManager.getTerm(termId3).maturityTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(
            accountManager.getTerm(termId3).discountRate,
            termDiscountRate3
        );
        assertEq(accountManager.getTerm(termId3).coupons.length, 3);
        assertEq(accountManager.getTerm(termId3).coupons[0].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId3).coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(
            accountManager.getTerm(termId3).coupons[0].discountRate,
            termDiscountRate3
        );
        assertEq(accountManager.getTerm(termId3).coupons[1].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId3).coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(
            accountManager.getTerm(termId3).coupons[1].discountRate,
            termDiscountRate2
        );
        assertEq(accountManager.getTerm(termId3).coupons[2].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId3).coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId3).coupons[2].discountRate,
            termDiscountRate1
        );

        assertEq(termTokens[3].id, termId4);
        assertEq(
            termTokens[3].maturityTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(termTokens[3].discountRate, termDiscountRate4);
        assertEq(termTokens[3].coupons.length, 4);
        assertEq(termTokens[3].coupons[0].rate, _couponRate);
        assertEq(
            termTokens[3].coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(termTokens[3].coupons[0].discountRate, termDiscountRate4);
        assertEq(termTokens[3].coupons[1].rate, _couponRate);
        assertEq(
            termTokens[3].coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(termTokens[3].coupons[1].discountRate, termDiscountRate3);
        assertEq(termTokens[3].coupons[2].rate, _couponRate);
        assertEq(
            termTokens[3].coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(termTokens[3].coupons[2].discountRate, termDiscountRate2);
        assertEq(termTokens[3].coupons[3].rate, _couponRate);
        assertEq(
            termTokens[3].coupons[3].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[3].coupons[3].discountRate, termDiscountRate1);
        assertEq(accountManager.getTerm(termId4).id, termId4);
        assertEq(
            accountManager.getTerm(termId4).maturityTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(
            accountManager.getTerm(termId4).discountRate,
            termDiscountRate4
        );
        assertEq(accountManager.getTerm(termId4).coupons.length, 4);
        assertEq(accountManager.getTerm(termId4).coupons[0].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId4).coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(
            accountManager.getTerm(termId4).coupons[0].discountRate,
            termDiscountRate4
        );
        assertEq(accountManager.getTerm(termId4).coupons[1].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId4).coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(
            accountManager.getTerm(termId4).coupons[1].discountRate,
            termDiscountRate3
        );
        assertEq(accountManager.getTerm(termId4).coupons[2].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId4).coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(
            accountManager.getTerm(termId4).coupons[2].discountRate,
            termDiscountRate2
        );
        assertEq(accountManager.getTerm(termId4).coupons[3].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId4).coupons[3].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId4).coupons[3].discountRate,
            termDiscountRate1
        );

        assertEq(termTokens[4].id, termId5);
        assertEq(
            termTokens[4].maturityTimestamp,
            termIssuer.maturityTimestamp(termId5)
        );
        assertEq(termTokens[4].discountRate, termDiscountRate5);
        assertEq(termTokens[4].coupons.length, 5);
        assertEq(termTokens[4].coupons[0].rate, _couponRate);
        assertEq(
            termTokens[4].coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId5)
        );
        assertEq(termTokens[4].coupons[0].discountRate, termDiscountRate5);
        assertEq(termTokens[4].coupons[1].rate, _couponRate);
        assertEq(
            termTokens[4].coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(termTokens[4].coupons[1].discountRate, termDiscountRate4);
        assertEq(termTokens[4].coupons[2].rate, _couponRate);
        assertEq(
            termTokens[4].coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(termTokens[4].coupons[2].discountRate, termDiscountRate3);
        assertEq(termTokens[4].coupons[3].rate, _couponRate);
        assertEq(
            termTokens[4].coupons[3].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(termTokens[4].coupons[3].discountRate, termDiscountRate2);
        assertEq(termTokens[4].coupons[4].rate, _couponRate);
        assertEq(
            termTokens[4].coupons[4].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(termTokens[4].coupons[4].discountRate, termDiscountRate1);
        assertEq(accountManager.getTerm(termId5).id, termId5);
        assertEq(
            accountManager.getTerm(termId5).maturityTimestamp,
            termIssuer.maturityTimestamp(termId5)
        );
        assertEq(
            accountManager.getTerm(termId5).discountRate,
            termDiscountRate5
        );
        assertEq(accountManager.getTerm(termId5).coupons.length, 5);
        assertEq(accountManager.getTerm(termId5).coupons[0].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId5).coupons[0].claimTimestamp,
            termIssuer.maturityTimestamp(termId5)
        );
        assertEq(
            accountManager.getTerm(termId5).coupons[0].discountRate,
            termDiscountRate5
        );
        assertEq(accountManager.getTerm(termId5).coupons[1].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId5).coupons[1].claimTimestamp,
            termIssuer.maturityTimestamp(termId4)
        );
        assertEq(
            accountManager.getTerm(termId5).coupons[1].discountRate,
            termDiscountRate4
        );
        assertEq(accountManager.getTerm(termId5).coupons[2].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId5).coupons[2].claimTimestamp,
            termIssuer.maturityTimestamp(termId3)
        );
        assertEq(
            accountManager.getTerm(termId5).coupons[2].discountRate,
            termDiscountRate3
        );
        assertEq(accountManager.getTerm(termId5).coupons[3].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId5).coupons[3].claimTimestamp,
            termIssuer.maturityTimestamp(termId2)
        );
        assertEq(
            accountManager.getTerm(termId5).coupons[3].discountRate,
            termDiscountRate2
        );
        assertEq(accountManager.getTerm(termId5).coupons[4].rate, _couponRate);
        assertEq(
            accountManager.getTerm(termId5).coupons[4].claimTimestamp,
            termIssuer.maturityTimestamp(termId1)
        );
        assertEq(
            accountManager.getTerm(termId5).coupons[4].discountRate,
            termDiscountRate1
        );

        for (
            uint256 i = termIssuer.latestID() + 1;
            i < termIssuer.latestID() + 40;
            i++
        ) {
            assertEq(accountManager.getTerm(i).id, i);
            assertEq(
                accountManager.getTerm(i).maturityTimestamp,
                termIssuer.maturityTimestamp(i)
            );
            assertEq(accountManager.getTerm(i).discountRate, 0);
            assertEq(accountManager.getTerm(i).coupons.length, 0);
        }

        for (uint256 i; i < termIssuer.earliestID(); i++) {
            assertEq(accountManager.getTerm(i).id, i);
            assertEq(
                accountManager.getTerm(i).maturityTimestamp,
                termIssuer.maturityTimestamp(i)
            );
            assertEq(accountManager.getTerm(i).discountRate, 0);
            assertEq(accountManager.getTerm(i).coupons.length, 0);
        }
    }
}
