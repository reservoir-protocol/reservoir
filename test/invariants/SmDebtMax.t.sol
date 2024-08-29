// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "forge-std/InvariantTest.sol";

import "./InvariantMain.t.sol";

uint256 constant SM_DEBT_MAX = 10_000_000e18;

contract Handler is CommonBase, StdCheats, StdUtils {
    CreditEnforcer private creditEnforcer;

    SavingModule private sm;

    Stablecoin private rusd;
    Savingcoin private srusd;

    constructor(
        Stablecoin _rusd,
        Savingcoin _srusd,
        CreditEnforcer _creditEnforcer,
        SavingModule _sm
    ) {
        creditEnforcer = _creditEnforcer;
        rusd = _rusd;
        sm = _sm;
        srusd = _srusd;
    }

    function mintSavingoin(uint256 _amount) external {
        _amount = bound(_amount, 1e18, SM_DEBT_MAX);
        rusd.mint(address(this), _amount);
        rusd.approve(address(sm), _amount);
        creditEnforcer.mintSavingcoin(_amount);
    }

    function redeemSavingcoin(uint256 _amount) external {
        _amount = bound(_amount, 0, srusd.balanceOf(address(this)));
        srusd.approve(address(sm), _amount);
        sm.redeem(_amount);
    }
}

contract SmDebtMaxInvariantTest is InvariantMainTest {
    Handler private handler;

    function setUp() external {
        _setUp();

        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        creditEnforcer.setSMDebtMax(SM_DEBT_MAX);

        handler = new Handler(rusd, srusd, creditEnforcer, sm);

        rusd.grantRole(rusd.MINTER(), address(handler));

        targetContract(address(handler));
    }

    function invariant_sm_debt_max_never_surpassed() external {
        assertTrue(sm.totalDebt() <= creditEnforcer.smDebtMax());
    }
}
