// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

contract E2EScenario1Test is E2EMainTest {
    function testScenario1() external {
        // Set timestamp to January 1st, 2024
        skip(1704085200 - block.timestamp);

        // Set CE variables
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        uint256 earliestId = termIssuer.earliestID();
        uint256 latestId = termIssuer.latestID();

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.08e12
        );

        // Set Bond options
        for (uint i = earliestId; i <= latestId; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);

            termIssuer.setDiscountRate(i, 0.000210874 * 1e9);
        }

        uint256 bond1 = latestId - 1;
        uint256 bond2 = latestId - 2;

        // Mint 100'000 USDC
        usdc.mint(address(this), 1_000_000e6);

        // Swap 100'000 USDC for rusd
        usdc.approve(address(psm), 100_000e6);
        creditEnforcer.mintStablecoin(address(this), 100_000e6);

        // Buy 1'000 brusd (second last one)
        {
            uint256 amount = 1_000e18;
            (uint256 cost, ) = accountManager.getQuote(bond1, amount);
            rusd.approve(address(accountManager), cost);
            accountManager.mintTerm(bond1, amount);
        }

        skip(92.5 days);

        // Repurchase 1'000 more of the same brusd
        {
            uint256 amount = 1_000e18;
            (uint256 cost, ) = accountManager.getQuote(bond1, amount);
            rusd.approve(address(accountManager), cost);
            accountManager.mintTerm(bond1, amount);
        }

        // Buy 1'000 brusd of previous index of the one we own
        {
            uint256 amount = 1_000e18;
            (uint256 cost, ) = accountManager.getQuote(bond2, amount);
            rusd.approve(address(accountManager), cost);
            accountManager.mintTerm(bond2, amount);
        }

        skip(365 days);

        // Get rid of all rusd to calculate rusd gained from bonds
        rusd.transfer(address(1), rusd.balanceOf(address(this)));

        // Claim and Redeem the first type of brusd bought
        {
            AccountManager.Position memory position = accountManager
                .getUserPosition(address(this), bond1);
            for (uint i = 0; i < position.coupons.length; i++) {
                accountManager.claim(bond1);
            }
            accountManager.redeem(bond1);
        }

        // Claim and Redeem the second type of brusd bought
        {
            AccountManager.Position memory position = accountManager
                .getUserPosition(address(this), bond2);
            for (uint i = 0; i < position.coupons.length; i++) {
                accountManager.claim(bond2);
            }
            accountManager.redeem(bond2);
        }

        assertEq(rusd.balanceOf(address(this)), 3_180e18);
    }
}
