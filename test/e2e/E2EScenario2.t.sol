// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

// - 3 wallets each with 10 M
//  - use different yield and coupon than scenario 1
//  - available bonds make (82 - 86)
//  - user 1 buys 1 M of ID 84
//  - user 2 buys 2 M of ID 86
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  -  skip to first claim date
//  - user 3 buys 4 M of ID 83
//  - user 2 claims coupon (user 1 does not)
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - skip to second claim date
//  - all users claim all avialable coupons and principle (user 1 will have at least 2 coupons)
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - then get creative

contract E2EScenario2Test is E2EMainTest {
    address public constant WALLET_1 = address(1);
    address public constant WALLET_2 = address(2);
    address public constant WALLET_3 = address(3);

    uint256 public constant YIELD = 0.000000180242e12;
    uint256 public constant C_RATE = 0.06e12;
    uint256 public constant STARTING_BOND_ID = 82;

    uint256 public constant W1_STARTING_rusd = 10_000_000e18;
    uint256 public constant W2_STARTING_rusd = 10_000_000e18;
    uint256 public constant W3_STARTING_rusd = 10_000_000e18;

    uint256 public constant W1_PURCHASE_AMOUNT = 1_000_000e18;
    uint256 public constant W2_PURCHASE_AMOUNT = 2_000_000e18;
    uint256 public constant W3_PURCHASE_AMOUNT = 4_000_000e18;

    uint256 public constant W1_BOND_ID = 84;
    uint256 public constant W2_BOND_ID = 86;
    uint256 public constant W3_BOND_ID = 83;

    function testScenario2() external {
        // use different yield and coupon than scenario 1
        // available bonds make (82 - 86)
        _setVariables(STARTING_BOND_ID, YIELD, C_RATE);

        // 3 wallets each with 10m us
        _mintrusd(WALLET_1, W1_STARTING_rusd / 1e12);
        _mintrusd(WALLET_2, W2_STARTING_rusd / 1e12);
        _mintrusd(WALLET_3, W3_STARTING_rusd / 1e12);

        assertEq(rusd.balanceOf(WALLET_1), W1_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_2), W2_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_3), W3_STARTING_rusd);

        // user 1 buys 1 M of ID 84
        _buyBond(WALLET_1, W1_PURCHASE_AMOUNT, W1_BOND_ID);
        // user 2 buys 2 M of ID 86
        _buyBond(WALLET_2, W2_PURCHASE_AMOUNT, W2_BOND_ID);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        uint256 wallet1cost1 = _applyDiscountFull(
            W1_PURCHASE_AMOUNT,
            W1_BOND_ID
        );
        uint256 wallet2cost1 = _applyDiscountFull(
            W2_PURCHASE_AMOUNT,
            W2_BOND_ID
        );

        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            W1_BOND_ID,
            false,
            wallet1cost1,
            W1_PURCHASE_AMOUNT,
            1,
            C_RATE,
            3,
            0
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            W2_BOND_ID,
            false,
            wallet2cost1,
            W2_PURCHASE_AMOUNT,
            1,
            C_RATE,
            5,
            0
        );
        assertEq(rusd.balanceOf(WALLET_3), W3_STARTING_rusd);
        assertEq(accountManager.accountListLength(WALLET_3), 0);

        //  -  skip to first claim date
        skip(DELTA);

        //  - user 3 buys 4 M of ID 83
        _buyBond(WALLET_3, W3_PURCHASE_AMOUNT, W3_BOND_ID);

        //  - user 2 claims coupon (user 1 does not)
        _claimCoupon(WALLET_2, W2_BOND_ID);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        uint256 wallet3cost1 = _applyDiscountFull(
            W3_PURCHASE_AMOUNT,
            W3_BOND_ID
        );

        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            W1_BOND_ID,
            false,
            wallet1cost1,
            W1_PURCHASE_AMOUNT,
            1,
            C_RATE,
            3,
            0
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            W2_BOND_ID,
            false,
            wallet2cost1,
            W2_PURCHASE_AMOUNT,
            1,
            C_RATE,
            4,
            1
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            W3_BOND_ID,
            false,
            wallet3cost1,
            W3_PURCHASE_AMOUNT,
            1,
            C_RATE,
            1,
            0
        );

        //  - skip to second claim date
        skip(DELTA);

        //  - all users claim all avialable coupons and principle (user 1 will have at least 2 coupons)
        _claimCoupon(WALLET_1, W1_BOND_ID);
        _claimCoupon(WALLET_1, W1_BOND_ID);
        _claimCoupon(WALLET_2, W2_BOND_ID);
        _claimCoupon(WALLET_3, W3_BOND_ID);
        _redeemBond(WALLET_3, W3_BOND_ID);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            W1_BOND_ID,
            false,
            wallet1cost1,
            W1_PURCHASE_AMOUNT,
            1,
            C_RATE,
            1,
            2
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            W2_BOND_ID,
            false,
            wallet2cost1,
            W2_PURCHASE_AMOUNT,
            1,
            C_RATE,
            3,
            2
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            W3_BOND_ID,
            true,
            wallet3cost1,
            W3_PURCHASE_AMOUNT,
            0,
            C_RATE,
            0,
            1
        );
    }
}
