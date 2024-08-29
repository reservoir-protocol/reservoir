// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

contract E2EScenario2Test is E2EMainTest {
    address public eoa1 = vm.addr(1);
    address public eoa2 = vm.addr(2);
    address public eoa3 = vm.addr(3);
    address public eoa4 = vm.addr(4);
    address public eoa5 = vm.addr(5);
    address public eoa6 = vm.addr(6);
    address public eoa7 = vm.addr(7);
    address public eoa8 = vm.addr(8);
    address public eoa9 = vm.addr(9);
    address public eoa10 = vm.addr(10);
    address public eoa11 = vm.addr(11);
    address public eoa12 = vm.addr(12);
    address public eoa13 = vm.addr(13);
    address public eoa14 = vm.addr(14);
    address public eoa15 = vm.addr(15);
    address public eoa16 = vm.addr(16);
    address public eoa17 = vm.addr(17);
    address public eoa18 = vm.addr(18);

    uint256[] public termIds;

    function testScenario8() external {
        _setVariables(2, 0.000000180242e12, 0.08e12);

        _mintRusdAndBuyTerm(eoa1, 1_000e18, 2);
        _mintRusdAndBuyTerm(eoa1, 2_200e18, 6);

        _mintRusdAndBuyTerm(eoa2, 2_000e18, 3);

        _mintRusdAndBuyTerm(eoa3, 10_000e18, 4);

        _mintRusdAndBuyTerm(eoa4, 5_000e18, 5);
        _mintRusdAndBuyTerm(eoa4, 500e18, 2);

        _mintRusdAndBuyTerm(eoa5, 100e18, 6);

        termIds.push(2);
        termIds.push(6);
        _checkState(eoa1, termIds);

        termIds.push(3);
        _checkState(eoa2, termIds);

        termIds.push(4);
        _checkState(eoa3, termIds);

        termIds.push(5);
        termIds.push(2);
        _checkState(eoa4, termIds);

        termIds.push(6);
        _checkState(eoa5, termIds);

        skip(DELTA);

        _claimCoupon(eoa1, 2);
        _redeemBond(eoa1, 2);

        _mintRusdAndBuyTerm(eoa4, 1_000e18, 7);

        _mintRusdAndBuyTerm(eoa6, 1_000e18, 3);

        _mintRusdAndBuyTerm(eoa7, 2_000e18, 4);

        _mintRusdAndBuyTerm(eoa8, 10_000e18, 5);

        _mintRusdAndBuyTerm(eoa9, 5_000e18, 6);

        _mintRusdAndBuyTerm(eoa10, 500e18, 7);

        termIds.push(6);
        _checkState(eoa1, termIds);

        termIds.push(3);
        _checkState(eoa2, termIds);

        termIds.push(4);
        _checkState(eoa3, termIds);

        termIds.push(5);
        termIds.push(2);
        termIds.push(7);
        _checkState(eoa4, termIds);

        termIds.push(6);
        _checkState(eoa5, termIds);

        termIds.push(3);
        _checkState(eoa6, termIds);

        termIds.push(4);
        _checkState(eoa7, termIds);

        termIds.push(5);
        _checkState(eoa8, termIds);

        termIds.push(6);
        _checkState(eoa9, termIds);

        termIds.push(7);
        _checkState(eoa10, termIds);

        skip(DELTA);
        skip(DELTA);

        // 5 earliest

        _claimCoupon(eoa2, 3);
        _claimCoupon(eoa2, 3);
        _redeemBond(eoa2, 3);

        _claimCoupon(eoa3, 4);
        _claimCoupon(eoa3, 4);
        _claimCoupon(eoa3, 4);
        _redeemBond(eoa3, 4);

        _claimCoupon(eoa4, 2);
        _redeemBond(eoa4, 2);

        _claimCoupon(eoa6, 3);
        _redeemBond(eoa6, 3);

        _claimCoupon(eoa7, 4);
        _claimCoupon(eoa7, 4);
        _redeemBond(eoa7, 4);

        termIds.push(6);
        _checkState(eoa1, termIds);

        _checkState(eoa2, termIds);

        _checkState(eoa3, termIds);

        termIds.push(5);
        termIds.push(7);
        _checkState(eoa4, termIds);

        termIds.push(6);
        _checkState(eoa5, termIds);

        _checkState(eoa6, termIds);

        _checkState(eoa7, termIds);

        termIds.push(5);
        _checkState(eoa8, termIds);

        termIds.push(6);
        _checkState(eoa9, termIds);

        termIds.push(7);
        _checkState(eoa10, termIds);

        _mintRusdAndBuyTerm(eoa8, 1_000e18, 5);
        _mintRusdAndBuyTerm(eoa8, 2_000e18, 5);
        _mintRusdAndBuyTerm(eoa8, 2_000e18, 5);

        termIds.push(5);
        _checkState(eoa8, termIds);

        skip(DELTA);
        skip(DELTA);

        // 7 earliest

        _mintRusdAndBuyTerm(eoa10, 500e18, 8);
        _mintRusdAndBuyTerm(eoa10, 500e18, 9);
        _mintRusdAndBuyTerm(eoa10, 500e18, 10);
        _mintRusdAndBuyTerm(eoa10, 500e18, 11);

        _mintRusdAndBuyTerm(eoa11, 2_000e18, 8);
        _mintRusdAndBuyTerm(eoa11, 500e18, 11);
        _mintRusdAndBuyTerm(eoa11, 500e18, 9);

        _mintRusdAndBuyTerm(eoa12, 500e18, 11);

        _mintRusdAndBuyTerm(eoa13, 500e18, 8);

        _mintRusdAndBuyTerm(eoa14, 500e18, 7);

        _mintRusdAndBuyTerm(eoa15, 500e18, 7);

        termIds.push(6);
        _checkState(eoa1, termIds);

        termIds.push(5);
        termIds.push(7);
        _checkState(eoa4, termIds);

        termIds.push(6);
        _checkState(eoa5, termIds);

        termIds.push(5);
        _checkState(eoa8, termIds);

        termIds.push(6);
        _checkState(eoa9, termIds);

        termIds.push(7);
        termIds.push(8);
        termIds.push(9);
        termIds.push(10);
        termIds.push(11);
        _checkState(eoa10, termIds);

        termIds.push(8);
        termIds.push(11);
        termIds.push(9);
        _checkState(eoa11, termIds);

        termIds.push(11);
        _checkState(eoa12, termIds);

        termIds.push(8);
        _checkState(eoa13, termIds);

        termIds.push(7);
        _checkState(eoa14, termIds);

        termIds.push(7);
        _checkState(eoa15, termIds);

        skip(DELTA);
        skip(DELTA);
        skip(DELTA);

        // 10 earliest

        _mintRusdAndBuyTerm(eoa16, 10_000e18, 14);
        _mintRusdAndBuyTerm(eoa16, 10_000e18, 14);
        _mintRusdAndBuyTerm(eoa16, 1_000e18, 11);

        _mintRusdAndBuyTerm(eoa17, 1_000e18, 13);

        _mintRusdAndBuyTerm(eoa18, 1_000e18, 14);
        _mintRusdAndBuyTerm(eoa18, 1_000e18, 13);
        _mintRusdAndBuyTerm(eoa18, 1_000e18, 10);
        _mintRusdAndBuyTerm(eoa18, 1_000e18, 12);

        termIds.push(6);
        _checkState(eoa1, termIds);

        termIds.push(5);
        termIds.push(7);
        _checkState(eoa4, termIds);

        termIds.push(6);
        _checkState(eoa5, termIds);

        termIds.push(5);
        _checkState(eoa8, termIds);

        termIds.push(6);
        _checkState(eoa9, termIds);

        termIds.push(7);
        termIds.push(8);
        termIds.push(9);
        termIds.push(10);
        termIds.push(11);
        _checkState(eoa10, termIds);

        termIds.push(8);
        termIds.push(11);
        termIds.push(9);
        _checkState(eoa11, termIds);

        termIds.push(11);
        _checkState(eoa12, termIds);

        termIds.push(8);
        _checkState(eoa13, termIds);

        termIds.push(7);
        _checkState(eoa14, termIds);

        termIds.push(7);
        _checkState(eoa15, termIds);

        termIds.push(14);
        termIds.push(11);
        _checkState(eoa16, termIds);

        termIds.push(13);
        _checkState(eoa17, termIds);

        termIds.push(14);
        termIds.push(13);
        termIds.push(10);
        termIds.push(12);
        _checkState(eoa18, termIds);

        skip(DELTA);
        skip(DELTA);
        skip(DELTA);
        skip(DELTA);
        skip(DELTA);

        _claimCoupon(eoa1, 6);
        _claimCoupon(eoa1, 6);
        _claimCoupon(eoa1, 6);
        _claimCoupon(eoa1, 6);
        _claimCoupon(eoa1, 6);
        _redeemBond(eoa1, 6);

        _checkState(eoa1, termIds);

        _claimCoupon(eoa4, 5);
        _claimCoupon(eoa4, 5);
        _claimCoupon(eoa4, 5);
        _claimCoupon(eoa4, 5);
        _redeemBond(eoa4, 5);

        termIds.push(7);
        _checkState(eoa4, termIds);

        _claimCoupon(eoa4, 7);
        _claimCoupon(eoa4, 7);
        _claimCoupon(eoa4, 7);
        _claimCoupon(eoa4, 7);
        _claimCoupon(eoa4, 7);
        _redeemBond(eoa4, 7);

        _checkState(eoa4, termIds);

        _claimCoupon(eoa5, 6);
        _claimCoupon(eoa5, 6);
        _claimCoupon(eoa5, 6);
        _claimCoupon(eoa5, 6);
        _claimCoupon(eoa5, 6);
        _redeemBond(eoa5, 6);

        _checkState(eoa5, termIds);

        _claimCoupon(eoa8, 5);
        _claimCoupon(eoa8, 5);
        _claimCoupon(eoa8, 5);
        _redeemBond(eoa8, 5);

        _checkState(eoa8, termIds);

        _claimCoupon(eoa9, 6);
        _claimCoupon(eoa9, 6);
        _claimCoupon(eoa9, 6);
        _claimCoupon(eoa9, 6);
        _redeemBond(eoa9, 6);

        _checkState(eoa9, termIds);

        _claimCoupon(eoa12, 11);
        _claimCoupon(eoa12, 11);
        _claimCoupon(eoa12, 11);
        _claimCoupon(eoa12, 11);
        _claimCoupon(eoa12, 11);
        _redeemBond(eoa12, 11);

        _checkState(eoa12, termIds);

        _claimCoupon(eoa13, 8);
        _claimCoupon(eoa13, 8);
        _redeemBond(eoa13, 8);

        _checkState(eoa13, termIds);

        _claimCoupon(eoa14, 7);
        _redeemBond(eoa14, 7);

        _checkState(eoa14, termIds);

        _claimCoupon(eoa15, 7);
        _redeemBond(eoa15, 7);

        _checkState(eoa15, termIds);

        _claimCoupon(eoa17, 13);
        _claimCoupon(eoa17, 13);
        _claimCoupon(eoa17, 13);
        _claimCoupon(eoa17, 13);
        _redeemBond(eoa17, 13);

        _checkState(eoa17, termIds);

        _claimCoupon(eoa10, 10);
        _claimCoupon(eoa10, 10);
        _claimCoupon(eoa10, 10);
        _claimCoupon(eoa10, 10);
        _redeemBond(eoa10, 10);

        termIds.push(7);
        termIds.push(8);
        termIds.push(9);
        termIds.push(11);
        _checkState(eoa10, termIds);

        _claimCoupon(eoa10, 7);
        _claimCoupon(eoa10, 7);
        _claimCoupon(eoa10, 7);
        _claimCoupon(eoa10, 7);
        _claimCoupon(eoa10, 7);
        _redeemBond(eoa10, 7);

        termIds.push(11);
        termIds.push(8);
        termIds.push(9);
        _checkState(eoa10, termIds);

        _claimCoupon(eoa10, 11);
        _claimCoupon(eoa10, 11);
        _claimCoupon(eoa10, 11);
        _claimCoupon(eoa10, 11);
        _claimCoupon(eoa10, 11);
        _redeemBond(eoa10, 11);

        termIds.push(9);
        termIds.push(8);
        _checkState(eoa10, termIds);

        _claimCoupon(eoa10, 8);
        _claimCoupon(eoa10, 8);
        _redeemBond(eoa10, 8);

        termIds.push(9);
        _checkState(eoa10, termIds);

        _claimCoupon(eoa10, 9);
        _claimCoupon(eoa10, 9);
        _claimCoupon(eoa10, 9);
        _redeemBond(eoa10, 9);

        _checkState(eoa10, termIds);

        _claimCoupon(eoa11, 9);
        _claimCoupon(eoa11, 9);
        _claimCoupon(eoa11, 9);
        _redeemBond(eoa11, 9);

        termIds.push(8);
        termIds.push(11);
        _checkState(eoa11, termIds);

        _claimCoupon(eoa11, 11);
        _claimCoupon(eoa11, 11);
        _claimCoupon(eoa11, 11);
        _claimCoupon(eoa11, 11);
        _claimCoupon(eoa11, 11);
        _redeemBond(eoa11, 11);

        termIds.push(8);
        _checkState(eoa11, termIds);

        _claimCoupon(eoa11, 8);
        _claimCoupon(eoa11, 8);
        _redeemBond(eoa11, 8);

        _checkState(eoa11, termIds);

        _claimCoupon(eoa16, 14);
        _claimCoupon(eoa16, 14);
        _claimCoupon(eoa16, 14);
        _claimCoupon(eoa16, 14);
        _claimCoupon(eoa16, 14);
        _redeemBond(eoa16, 14);

        termIds.push(11);
        _checkState(eoa16, termIds);

        _claimCoupon(eoa16, 11);
        _claimCoupon(eoa16, 11);
        _redeemBond(eoa16, 11);

        _checkState(eoa16, termIds);

        _claimCoupon(eoa18, 13);
        _claimCoupon(eoa18, 13);
        _claimCoupon(eoa18, 13);
        _claimCoupon(eoa18, 13);
        _redeemBond(eoa18, 13);

        termIds.push(14);
        termIds.push(12);
        termIds.push(10);
        _checkState(eoa18, termIds);

        _claimCoupon(eoa18, 14);
        _claimCoupon(eoa18, 14);
        _claimCoupon(eoa18, 14);
        _claimCoupon(eoa18, 14);
        _claimCoupon(eoa18, 14);
        _redeemBond(eoa18, 14);

        termIds.push(10);
        termIds.push(12);
        _checkState(eoa18, termIds);

        _claimCoupon(eoa18, 10);
        _redeemBond(eoa18, 10);

        termIds.push(12);
        _checkState(eoa18, termIds);

        _claimCoupon(eoa18, 12);
        _claimCoupon(eoa18, 12);
        _claimCoupon(eoa18, 12);
        _redeemBond(eoa18, 12);

        _checkState(eoa18, termIds);

        // Check every position has been closed
        _checkState(eoa1, termIds);
        _checkState(eoa2, termIds);
        _checkState(eoa3, termIds);
        _checkState(eoa4, termIds);
        _checkState(eoa5, termIds);
        _checkState(eoa6, termIds);
        _checkState(eoa7, termIds);
        _checkState(eoa8, termIds);
        _checkState(eoa9, termIds);
        _checkState(eoa10, termIds);
        _checkState(eoa11, termIds);
        _checkState(eoa12, termIds);
        _checkState(eoa13, termIds);
        _checkState(eoa14, termIds);
        _checkState(eoa15, termIds);
        _checkState(eoa16, termIds);
        _checkState(eoa17, termIds);
        _checkState(eoa18, termIds);
    }

    function _mintRusdAndBuyTerm(
        address eoa,
        uint256 amount,
        uint256 termId
    ) internal {
        (uint256 cost, ) = accountManager.getQuote(termId, amount);
        _mintrusd(eoa, cost);
        _buyBond(eoa, amount, termId);
    }

    function _checkState(address _eoa, uint256[] memory _termIds) internal {
        uint256 length = _termIds.length;

        assertEq(accountManager.accountListLength(_eoa), length);
        assertEq(accountManager.getCurrentHoldings(_eoa).length, length);
        assertEq(accountManager.getAccountList(_eoa).length, length);

        for (uint256 i; i < length; i++) {
            assertEq(accountManager.getCurrentHoldings(_eoa)[i].index, i);
            assertEq(accountManager.getAccountList(_eoa)[i], _termIds[i]);

            // clean up the global state to fill variables in for next check
            termIds.pop();
        }
    }
}
