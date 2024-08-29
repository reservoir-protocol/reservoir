// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {ITerm, Term} from "src/Term.sol";
import {ITermIssuer, TermIssuer} from "src/TermIssuer.sol";

import {ISavingModule, SavingModule} from "src/SavingModule.sol";
import {IPegStabilityModule, PegStabilityModule} from "src/PegStabilityModule.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {ICreditEnforcer, CreditEnforcer} from "src/CreditEnforcer.sol";

import {AccountManager} from "src/AccountManager.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract E2EMainTest is Test {
    uint256 public constant DELTA = 90 days;

    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    Stablecoin rusd;
    Savingcoin srusd;

    Term term;
    TermIssuer termIssuer;

    SavingModule sm;
    PegStabilityModule psm;

    CreditEnforcer creditEnforcer;

    AccountManager accountManager;

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        srusd = new Savingcoin(address(this), "Reservoir Savingcoin", "srUSD");

        term = new Term(address(this), "https://reservoir.io/terms/");

        // = = =

        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        rusd.grantRole(rusd.MINTER(), address(psm));

        // = = =

        termIssuer = new TermIssuer(
            address(this),
            DELTA, //
            0,
            //
            ITerm(address(term)),
            IToken(address(rusd))
        );

        rusd.grantRole(rusd.MINTER(), address(termIssuer));
        term.grantRole(term.MINTER(), address(termIssuer));

        // = = =

        sm = new SavingModule(
            address(this),
            IToken(address(rusd)),
            IToken(address(srusd))
        );

        creditEnforcer = new CreditEnforcer(
            address(this),
            IERC20(address(usdc)),
            ITermIssuer(address(termIssuer)),
            IPegStabilityModule(address(psm)),
            ISavingModule(address(sm))
        );

        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));
    }

    function _setVariables(
        uint256 earliestID,
        uint256 yield,
        uint256 couponRate
    ) internal {
        skip((earliestID - 1) * DELTA - block.timestamp);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            couponRate
        );

        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setDuration(30 days);
        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        for (uint256 i = earliestID; i <= earliestID + 100; i++) {
            creditEnforcer.setTermDebtMax(i, type(uint256).max);

            termIssuer.setDiscountRate(i, yield);
        }
    }

    function _mintrusd(address wallet, uint256 amount) internal {
        usdc.mint(wallet, amount);
        vm.prank(wallet);
        usdc.approve(address(psm), amount);
        vm.prank(wallet);
        creditEnforcer.mintStablecoin(wallet, amount);
    }

    function _buyBond(
        address wallet,
        uint256 amount,
        uint256 bondId
    ) internal returns (uint256) {
        (uint256 cost, ) = accountManager.getQuote(bondId, amount);
        vm.prank(wallet);
        rusd.approve(address(accountManager), cost);
        vm.prank(wallet);
        accountManager.mintTerm(bondId, amount);
        return cost;
    }

    function _applyDiscountFull(
        uint256 amount,
        uint256 bondId
    ) internal view returns (uint256) {
        uint256 bondWithDiscount = termIssuer.applyDiscount(
            amount,
            termIssuer.maturityTimestamp(bondId),
            termIssuer.getDiscountRate(bondId)
        );
        uint256 couponsWithDiscount;

        uint256 couponValue = (accountManager.couponRate() * amount) /
            (4 * 1e12);

        uint256 earliestID = termIssuer.earliestID();
        uint256 couponCount = bondId >= earliestID
            ? bondId - earliestID + 1
            : 0;

        for (uint256 i = 0; i < couponCount; i++) {
            couponsWithDiscount += termIssuer.applyDiscount(
                couponValue,
                termIssuer.maturityTimestamp(bondId - i),
                termIssuer.getDiscountRate(bondId - i)
            );
        }

        return bondWithDiscount + couponsWithDiscount;
    }

    function _claimCoupon(address wallet, uint256 bondId) internal {
        vm.prank(wallet);
        accountManager.claim(bondId);
    }

    function _redeemBond(address wallet, uint256 bondId) internal {
        vm.prank(wallet);
        accountManager.redeem(bondId);
    }

    function _couponGain(
        uint256 cRate,
        uint256 amount,
        uint256 claimCount
    ) internal pure returns (uint256) {
        return ((cRate * amount) / (4 * 1e12)) * claimCount;
    }

    function _checkUserState(
        address wallet,
        uint256 startingrusd,
        uint256 bondId,
        bool redeemed,
        uint256 totalCost,
        uint256 purchaseAmount,
        uint256 accountListLength,
        uint256 couponRate,
        uint256 couponLength,
        uint256 totalCouponsClaimed
    ) internal {
        if (redeemed) {
            assertApproxEqAbs(
                rusd.balanceOf(wallet),
                startingrusd +
                    _couponGain(
                        couponRate,
                        purchaseAmount,
                        totalCouponsClaimed
                    ) +
                    purchaseAmount -
                    totalCost,
                1
            );
            assertEq(
                accountManager.getUserPosition(wallet, bondId).principle,
                0
            );
        } else {
            assertEq(
                totalCost + rusd.balanceOf(wallet),
                startingrusd +
                    _couponGain(couponRate, purchaseAmount, totalCouponsClaimed)
            );
            assertEq(accountManager.getAccountList(wallet)[0], bondId);
            assertEq(
                accountManager.getUserPosition(wallet, bondId).principle,
                purchaseAmount
            );
        }
        assertEq(accountManager.accountListLength(wallet), accountListLength);
        assertEq(accountManager.getUserPosition(wallet, bondId).index, 0);
        assertEq(
            accountManager.getUserPosition(wallet, bondId).coupons.length,
            couponLength
        );
        for (uint256 i; i < couponLength; i++) {
            assertApproxEqAbs(
                accountManager.getUserPosition(wallet, bondId).coupons[i],
                (couponRate * purchaseAmount) / (4 * 1e12),
                1
            );
        }
    }
}
