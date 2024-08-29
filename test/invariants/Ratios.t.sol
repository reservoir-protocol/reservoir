// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

import "forge-std/InvariantTest.sol";

import "./InvariantMain.t.sol";

uint256 constant TERM_DEBT_MAX_1 = 10_000_000e18;
uint256 constant TERM_DEBT_MAX_2 = 2_000_000e18;
uint256 constant TERM_DEBT_MAX_3 = 11_000_000e18;
uint256 constant TERM_DEBT_MAX_4 = 6_750_000e18;
uint256 constant TERM_DEBT_MAX_5 = 25_000_000e18;

uint256 constant PSM_DEBT_MAX = 125_000_000e6;
uint256 constant SM_DEBT_MAX = 100_000_000e18;

uint256 constant ASSET_RATIO_MIN = 1.05e6;
uint256 constant EQUITY_RATIO_MIN = 1.05e6;
uint256 constant LIQUIDITY_RATIO_MIN = 1.05e6;

contract Handler is CommonBase, StdCheats, StdUtils {
    CreditEnforcer private creditEnforcer;

    TermIssuer private termIssuer;

    ERC20DecimalsMock private usdc;
    Stablecoin private rusd;

    PegStabilityModule private psm;
    SavingModule private sm;

    Savingcoin private srusd;

    constructor(
        ERC20DecimalsMock _usdc,
        Stablecoin _rusd,
        Savingcoin _srusd,
        CreditEnforcer _creditEnforcer,
        PegStabilityModule _psm,
        SavingModule _sm,
        TermIssuer _termIssuer
    ) {
        creditEnforcer = _creditEnforcer;
        rusd = _rusd;
        termIssuer = _termIssuer;
        usdc = _usdc;
        psm = _psm;
        srusd = _srusd;
        sm = _sm;
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

    function mintTerm1(uint256 _amount) external {
        _amount = bound(_amount, 1e18, TERM_DEBT_MAX_1 / 2);
        uint256 cost = termIssuer.applyDiscount(
            _amount,
            termIssuer.maturityTimestamp(1),
            termIssuer.getDiscountRate(1)
        );
        rusd.mint(address(this), cost);
        rusd.approve(address(termIssuer), cost);
        creditEnforcer.mintTerm(1, _amount);
    }

    function mintTerm2(uint256 _amount) external {
        _amount = bound(_amount, 1e18, TERM_DEBT_MAX_2 / 2);
        uint256 cost = termIssuer.applyDiscount(
            _amount,
            termIssuer.maturityTimestamp(2),
            termIssuer.getDiscountRate(2)
        );
        rusd.mint(address(this), cost);
        rusd.approve(address(termIssuer), cost);
        creditEnforcer.mintTerm(2, _amount);
    }

    function mintTerm3(uint256 _amount) external {
        _amount = bound(_amount, 1e18, TERM_DEBT_MAX_3 / 2);
        uint256 cost = termIssuer.applyDiscount(
            _amount,
            termIssuer.maturityTimestamp(3),
            termIssuer.getDiscountRate(3)
        );
        rusd.mint(address(this), cost);
        rusd.approve(address(termIssuer), cost);
        creditEnforcer.mintTerm(3, _amount);
    }

    function mintTerm4(uint256 _amount) external {
        _amount = bound(_amount, 1e18, TERM_DEBT_MAX_4 / 2);
        uint256 cost = termIssuer.applyDiscount(
            _amount,
            termIssuer.maturityTimestamp(4),
            termIssuer.getDiscountRate(4)
        );
        rusd.mint(address(this), cost);
        rusd.approve(address(termIssuer), cost);
        creditEnforcer.mintTerm(4, _amount);
    }

    function mintTerm5(uint256 _amount) external {
        _amount = bound(_amount, 1e18, TERM_DEBT_MAX_5 / 2);
        uint256 cost = termIssuer.applyDiscount(
            _amount,
            termIssuer.maturityTimestamp(5),
            termIssuer.getDiscountRate(5)
        );
        rusd.mint(address(this), cost);
        rusd.approve(address(termIssuer), cost);
        creditEnforcer.mintTerm(5, _amount);
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

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
}

contract RatiosInvariantTest is InvariantMainTest {
    Handler private handler;

    function setUp() external {
        _setUp();

        creditEnforcer.setAssetRatioMin(ASSET_RATIO_MIN);
        creditEnforcer.setEquityRatioMin(EQUITY_RATIO_MIN);
        creditEnforcer.setLiquidityRatioMin(LIQUIDITY_RATIO_MIN);

        creditEnforcer.setTermDebtMax(1, TERM_DEBT_MAX_1);
        creditEnforcer.setTermDebtMax(2, TERM_DEBT_MAX_2);
        creditEnforcer.setTermDebtMax(3, TERM_DEBT_MAX_3);
        creditEnforcer.setTermDebtMax(4, TERM_DEBT_MAX_4);
        creditEnforcer.setTermDebtMax(5, TERM_DEBT_MAX_5);

        termIssuer.setDiscountRate(1, 0.00006859294e12);
        termIssuer.setDiscountRate(2, 0.00008221185e12);
        termIssuer.setDiscountRate(3, 0.00009583227e12);
        termIssuer.setDiscountRate(4, 0.00021675436e12);
        termIssuer.setDiscountRate(5, 0.00021675436e12);

        creditEnforcer.setPSMDebtMax(PSM_DEBT_MAX);
        creditEnforcer.setSMDebtMax(SM_DEBT_MAX);

        handler = new Handler(
            usdc,
            rusd,
            srusd,
            creditEnforcer,
            psm,
            sm,
            termIssuer
        );

        rusd.grantRole(rusd.MINTER(), address(handler));

        targetContract(address(handler));
    }

    function invariant_ratios_never_violated() external {
        assertTrue(
            creditEnforcer.assetRatio() >= creditEnforcer.assetRatioMin() ||
                creditEnforcer.assetRatio() == 0
        );
        assertTrue(
            creditEnforcer.equityRatio() >= creditEnforcer.equityRatioMin() ||
                creditEnforcer.equityRatio() == 0
        );
        assertTrue(
            creditEnforcer.liquidityRatio() >=
                creditEnforcer.liquidityRatioMin() ||
                creditEnforcer.assetRatio() == 0
        );
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
}
