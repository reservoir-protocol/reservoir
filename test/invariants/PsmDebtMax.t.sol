// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "forge-std/InvariantTest.sol";

import "./InvariantMain.t.sol";

uint256 constant PSM_DEBT_MAX = 10_000_000e6;

contract Handler is CommonBase, StdCheats, StdUtils {
    CreditEnforcer private creditEnforcer;
    ERC20DecimalsMock private usdc;

    PegStabilityModule private psm;

    Stablecoin private rusd;

    constructor(
        ERC20DecimalsMock _usdc,
        Stablecoin _rusd,
        CreditEnforcer _creditEnforcer,
        PegStabilityModule _psm
    ) {
        creditEnforcer = _creditEnforcer;
        usdc = _usdc;
        psm = _psm;
        rusd = _rusd;
    }

    function mintStablecoin(uint256 _amount) external {
        _amount = bound(_amount, 1e6, PSM_DEBT_MAX);
        usdc.mint(address(this), _amount);
        usdc.approve(address(psm), _amount);
        creditEnforcer.mintStablecoin(_amount);
    }

    function redeemStablecoin(uint256 _amount) external {
        _amount = bound(_amount, 0, rusd.balanceOf(address(this)));
        rusd.approve(address(psm), _amount);
        psm.redeem(_amount / 1e12);
    }
}

contract PsmDebtMaxInvariantTest is InvariantMainTest {
    Handler private handler;

    function setUp() external {
        _setUp();

        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        creditEnforcer.setPSMDebtMax(PSM_DEBT_MAX);

        handler = new Handler(usdc, rusd, creditEnforcer, psm);

        targetContract(address(handler));
    }

    function invariant_psm_debt_max_never_surpassed() external {
        assertTrue(psm.underlyingBalance() <= creditEnforcer.psmDebtMax());
    }
}
