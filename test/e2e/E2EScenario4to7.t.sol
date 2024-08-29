// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

contract E2EScenario4To7Test is E2EMainTest {
    function testScenario4() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0e12
        );

        termIssuer.setDiscountRate(1, 0.00006859294e12);
        termIssuer.setDiscountRate(2, 0.00008221185e12);
        termIssuer.setDiscountRate(3, 0.00009583227e12);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);

        usdc.mint(address(this), 1_000_000_000e6);
        usdc.approve(address(psm), 1_000_000_000e6);
        creditEnforcer.mintStablecoin(address(this), 1_000_000_000e6);

        rusd.approve(address(accountManager), type(uint256).max);

        uint256 rusdBefore = rusd.balanceOf(address(this));

        accountManager.mintTerm(1, 1.5e18);
        accountManager.mintTerm(2, 1.5e18);
        accountManager.mintTerm(3, 101.5e18);

        uint256 rusdAfter = rusd.balanceOf(address(this));

        assertApproxEqRel(rusdBefore - rusdAfter, 101.8763e18, 0.0001e18);
    }

    function testScenario5() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.06e12
        );

        termIssuer.setDiscountRate(1, 0.00005621911e12);
        termIssuer.setDiscountRate(2, 0.00007328951e12);
        termIssuer.setDiscountRate(3, 0.00008933117e12);
        termIssuer.setDiscountRate(4, 0.00009999954e12);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);
        creditEnforcer.setTermDebtMax(4, type(uint256).max);

        usdc.mint(address(this), 1_000_000_000e6);
        usdc.approve(address(psm), 1_000_000_000e6);
        creditEnforcer.mintStablecoin(address(this), 1_000_000_000e6);

        rusd.approve(address(accountManager), type(uint256).max);

        uint256 rusdBalance1 = rusd.balanceOf(address(this));

        accountManager.mintTerm(2, 1255.2e18);

        uint256 rusdBalance2 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance1 - rusdBalance2,
            termIssuer.applyDiscount(
                1255.2e18,
                termIssuer.maturityTimestamp(2),
                0.00007328951e12
            ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 1255.2e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005621911e12
                ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 1255.2e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007328951e12
                )
        );

        accountManager.mintTerm(4, 3007.88e18);

        uint256 rusdBalance3 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance2 - rusdBalance3,
            termIssuer.applyDiscount(
                3007.88e18,
                termIssuer.maturityTimestamp(4),
                0.00009999954e12
            ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 3007.88e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005621911e12
                ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 3007.88e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007328951e12
                ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 3007.88e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(3),
                    0.00008933117e12
                ) +
                termIssuer.applyDiscount(
                    (0.06e12 * 3007.88e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(4),
                    0.00009999954e12
                )
        );
    }

    function testScenario6() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.08e12
        );

        termIssuer.setDiscountRate(1, 0.00005418721e12);
        termIssuer.setDiscountRate(2, 0.00007000123e12);
        termIssuer.setDiscountRate(3, 0.00008213119e12);
        termIssuer.setDiscountRate(4, 0.00009229166e12);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);
        creditEnforcer.setTermDebtMax(4, type(uint256).max);

        usdc.mint(address(this), 1_000_000_000e6);
        usdc.approve(address(psm), 1_000_000_000e6);
        creditEnforcer.mintStablecoin(address(this), 1_000_000_000e6);

        rusd.approve(address(accountManager), type(uint256).max);

        uint256 rusdBalance1 = rusd.balanceOf(address(this));

        accountManager.mintTerm(2, 98_210e18);

        uint256 rusdBalance2 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance1 - rusdBalance2,
            termIssuer.applyDiscount(
                98_210e18,
                termIssuer.maturityTimestamp(2),
                0.00007000123e12
            ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 98_210e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005418721e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 98_210e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007000123e12
                )
        );

        accountManager.mintTerm(4, 50_001.5e18);

        uint256 rusdBalance3 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance2 - rusdBalance3,
            termIssuer.applyDiscount(
                50_001.5e18,
                termIssuer.maturityTimestamp(4),
                0.00009229166e12
            ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 50_001.5e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005418721e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 50_001.5e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007000123e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 50_001.5e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(3),
                    0.00008213119e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 50_001.5e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(4),
                    0.00009229166e12
                )
        );
    }

    function testScenario7() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.08e12
        );

        termIssuer.setDiscountRate(1, 0.00005418721e12);
        termIssuer.setDiscountRate(2, 0.00007000123e12);
        termIssuer.setDiscountRate(3, 0.00008213119e12);
        termIssuer.setDiscountRate(4, 0.00009229166e12);

        creditEnforcer.setTermDebtMax(1, type(uint256).max);
        creditEnforcer.setTermDebtMax(2, type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);
        creditEnforcer.setTermDebtMax(4, type(uint256).max);

        usdc.mint(address(this), 1_000_000_000e6);
        usdc.approve(address(psm), 1_000_000_000e6);
        creditEnforcer.mintStablecoin(address(this), 1_000_000_000e6);

        rusd.approve(address(accountManager), type(uint256).max);

        uint256 rusdBalance1 = rusd.balanceOf(address(this));

        accountManager.mintTerm(2, 4_300_156.2e18);

        uint256 rusdBalance2 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance1 - rusdBalance2,
            termIssuer.applyDiscount(
                4_300_156.2e18,
                termIssuer.maturityTimestamp(2),
                0.00007000123e12
            ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 4_300_156.2e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005418721e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 4_300_156.2e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007000123e12
                )
        );

        accountManager.mintTerm(4, 36_999_100.25e18);

        uint256 rusdBalance3 = rusd.balanceOf(address(this));

        assertEq(
            rusdBalance2 - rusdBalance3,
            termIssuer.applyDiscount(
                36_999_100.25e18,
                termIssuer.maturityTimestamp(4),
                0.00009229166e12
            ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 36_999_100.25e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(1),
                    0.00005418721e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 36_999_100.25e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(2),
                    0.00007000123e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 36_999_100.25e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(3),
                    0.00008213119e12
                ) +
                termIssuer.applyDiscount(
                    (0.08e12 * 36_999_100.25e18) / (4 * 1e12),
                    termIssuer.maturityTimestamp(4),
                    0.00009229166e12
                )
        );
    }
}

// 6% coupon and 8% coupon
// 6 months and 1 year
