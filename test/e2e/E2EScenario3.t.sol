// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

// - 5 wallets each with 10 M
//  - use different yield and coupon than scenario 1 & 2
//  - available bonds make (10 - 14)
//  - user 1 buys 2.2 M of ID 10
//  - 5 day passes
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - user 2 buys 102k of ID 10
//  - 5 day passes
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - yield of bond#10 decreases a bit
//  - user 1 buys 1.2 M of ID 10
//  - user 3 buys 3.71M of ID 14
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - skip to first claim date
//  - user 1 claims coupon and redeems bond #10
//  - user 3 claims coupon of bond #14
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - skip to redeem date of bond #14 - 1 day
//  - user 4 buys 1M of ID 14
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - skip to redeem date of bond #14
//  - user 4 claims and redeems bond #14
//  - user 2 claims coupon and redeems bond #10
//  - user 3 claims all coupons and redeems bond #14
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - user 5 buys 2.7M of ID 16
//  = check all balances (rUSD and brUSD using TI applyDiscount function)
//  - skip to starting of a bond #30
//  - user 5 claims all coupons and redeems bond #16
//  = check all balances (rUSD and brUSD using TI applyDiscount function)

contract E2EScenario3Test is E2EMainTest {
    address public constant WALLET_1 = address(1);
    address public constant WALLET_2 = address(2);
    address public constant WALLET_3 = address(3);
    address public constant WALLET_4 = address(4);
    address public constant WALLET_5 = address(5);

    uint256 public constant YIELD = 0.000000171103e12;
    uint256 public constant C_RATE = 0.077e12;
    uint256 public constant STARTING_BOND_ID = 10;

    uint256 public constant W1_STARTING_rusd = 10_000_000e18;
    uint256 public constant W2_STARTING_rusd = 10_000_000e18;
    uint256 public constant W3_STARTING_rusd = 10_000_000e18;
    uint256 public constant W4_STARTING_rusd = 10_000_000e18;
    uint256 public constant W5_STARTING_rusd = 10_000_000e18;

    // uint256 public constant W1_PURCHASE_AMOUNT_1 = 1_000_000e18;
    // uint256 public constant W1_PURCHASE_AMOUNT_2 = 1_000_000e18;
    // uint256 public constant W2_PURCHASE_AMOUNT_1 = 2_000_000e18;
    // uint256 public constant W3_PURCHASE_AMOUNT_1 = 4_000_000e18;

    // uint256 public constant W1_BOND_ID = 84;
    // uint256 public constant W2_BOND_ID = 86;
    // uint256 public constant W3_BOND_ID = 83;

    function testScenario3() external {
        //  - use different yield and coupon than scenario 1 & 2
        //  - available bonds make (10 - 14)
        _setVariables(STARTING_BOND_ID, YIELD, C_RATE);

        // 3 wallets each with 10 M
        _mintrusd(WALLET_1, W1_STARTING_rusd / 1e12);
        _mintrusd(WALLET_2, W2_STARTING_rusd / 1e12);
        _mintrusd(WALLET_3, W3_STARTING_rusd / 1e12);
        _mintrusd(WALLET_4, W3_STARTING_rusd / 1e12);
        _mintrusd(WALLET_5, W3_STARTING_rusd / 1e12);

        assertEq(rusd.balanceOf(WALLET_1), W1_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_2), W2_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_3), W3_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_4), W2_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_5), W2_STARTING_rusd);

        // user 1 buys 2.2 M of ID 10
        _buyBond(WALLET_1, 2_200_000e18, 10);
        uint256 wallet1cost1 = _applyDiscountFull(2_200_000e18, 10);

        //  - 5 day passes
        skip(5 days);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            false,
            wallet1cost1,
            2_200_000e18,
            1,
            C_RATE,
            1,
            0
        );
        assertEq(rusd.balanceOf(WALLET_2), W2_STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_3), W3_STARTING_rusd);

        //  - user 2 buys 102k of ID 10
        _buyBond(WALLET_2, 102_000e18, 10);
        uint256 wallet2cost1 = _applyDiscountFull(102_000e18, 10);

        //  - 5 day passes
        skip(5 days);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            false,
            wallet1cost1,
            2_200_000e18,
            1,
            C_RATE,
            1,
            0
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            false,
            wallet2cost1,
            102_000e18,
            1,
            C_RATE,
            1,
            0
        );
        assertEq(rusd.balanceOf(WALLET_3), W3_STARTING_rusd);

        // TODO: Fix this rate to be realistic

        //  - yield of bond#10 decreases a bit
        termIssuer.setDiscountRate(10, 0.000131103 * 1e9);

        //  - user 1 buys 1.2 M of ID 10
        _buyBond(WALLET_1, 1_200_000e18, 10);
        uint256 wallet1cost2 = _applyDiscountFull(1_200_000e18, 10);
        //  - user 3 buys 3.71M of ID 14
        _buyBond(WALLET_3, 3_710_000e18, 14);
        uint256 wallet3cost1 = _applyDiscountFull(3_710_000e18, 14);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            false,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            1,
            C_RATE,
            1,
            0
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            false,
            wallet2cost1,
            102_000e18,
            1,
            C_RATE,
            1,
            0
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            false,
            wallet3cost1,
            3_710_000e18,
            1,
            C_RATE,
            5,
            0
        );

        //  -  skip to first claim date
        skip(DELTA - 10 days);

        //  - user 1 claims coupon and redeems bond #10
        _claimCoupon(WALLET_1, 10);
        _redeemBond(WALLET_1, 10);
        //  - user 3 claims coupon of bond #14
        _claimCoupon(WALLET_3, 14);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            true,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            false,
            wallet2cost1,
            102_000e18,
            1,
            C_RATE,
            1,
            0
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            false,
            wallet3cost1,
            3_710_000e18,
            1,
            C_RATE,
            4,
            1
        );

        //  - skip to redeem date of bond #14
        skip(DELTA * 4 - 1 days);

        //  - user 4 buys 1M of ID 14
        _buyBond(WALLET_4, 1_000_000e18, 14);
        uint256 wallet4cost1 = _applyDiscountFull(1_000_000e18, 14);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            true,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            false,
            wallet2cost1,
            102_000e18,
            1,
            C_RATE,
            1,
            0
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            false,
            wallet3cost1,
            3_710_000e18,
            1,
            C_RATE,
            4,
            1
        );
        _checkUserState(
            WALLET_4,
            W4_STARTING_rusd,
            14,
            false,
            wallet4cost1,
            1_000_000e18,
            1,
            C_RATE,
            1,
            0
        );

        //  - skip to redeem date of bond #14
        skip(1 days);

        //  - user 4 claims and redeems bond #14
        _claimCoupon(WALLET_4, 14);
        _redeemBond(WALLET_4, 14);
        //  - user 2 claims coupon and redeems bond #10
        _claimCoupon(WALLET_2, 10);
        _redeemBond(WALLET_2, 10);
        //  - user 3 claims all coupons and redeems bond #14
        _claimCoupon(WALLET_3, 14);
        _claimCoupon(WALLET_3, 14);
        _claimCoupon(WALLET_3, 14);
        _claimCoupon(WALLET_3, 14);
        _redeemBond(WALLET_3, 14);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            true,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            true,
            wallet2cost1,
            102_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            true,
            wallet3cost1,
            3_710_000e18,
            0,
            C_RATE,
            0,
            5
        );
        _checkUserState(
            WALLET_4,
            W4_STARTING_rusd,
            14,
            true,
            wallet4cost1,
            1_000_000e18,
            0,
            C_RATE,
            0,
            1
        );

        //  - user 5 buys 2.7M of ID 16
        _buyBond(WALLET_5, 2_700_000e18, 16);
        uint256 wallet5cost1 = _applyDiscountFull(2_700_000e18, 16);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            true,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            true,
            wallet2cost1,
            102_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            true,
            wallet3cost1,
            3_710_000e18,
            0,
            C_RATE,
            0,
            5
        );
        _checkUserState(
            WALLET_4,
            W4_STARTING_rusd,
            14,
            true,
            wallet4cost1,
            1_000_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_5,
            W5_STARTING_rusd,
            16,
            false,
            wallet5cost1,
            2_700_000e18,
            1,
            C_RATE,
            2,
            0
        );

        //  - skip to starting of a bond #30
        skip(DELTA * 15);

        //  - user 5 claims all coupons and redeems bond #16
        _claimCoupon(WALLET_5, 16);
        _claimCoupon(WALLET_5, 16);
        _redeemBond(WALLET_5, 16);

        //  = check all balances (rUSD and brUSD using TI applyDiscount function)
        _checkUserState(
            WALLET_1,
            W1_STARTING_rusd,
            10,
            true,
            wallet1cost1 + wallet1cost2,
            3_400_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            W2_STARTING_rusd,
            10,
            true,
            wallet2cost1,
            102_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_3,
            W3_STARTING_rusd,
            14,
            true,
            wallet3cost1,
            3_710_000e18,
            0,
            C_RATE,
            0,
            5
        );
        _checkUserState(
            WALLET_4,
            W4_STARTING_rusd,
            14,
            true,
            wallet4cost1,
            1_000_000e18,
            0,
            C_RATE,
            0,
            1
        );
        _checkUserState(
            WALLET_5,
            W5_STARTING_rusd,
            16,
            true,
            wallet5cost1,
            2_700_000e18,
            0,
            C_RATE,
            0,
            2
        );
    }
}
