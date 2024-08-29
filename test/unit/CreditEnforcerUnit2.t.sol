// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {IToken} from "src/interfaces/IToken.sol";

import {ITerm, Term} from "src/Term.sol";
import {ITermIssuer, TermIssuer} from "src/TermIssuer.sol";

import {ISavingModule, SavingModule} from "src/SavingModule.sol";
import {IPegStabilityModule, PegStabilityModule} from "src/PegStabilityModule.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {ICreditEnforcer, CreditEnforcer} from "src/CreditEnforcer.sol";

import {AccountManager} from "src/AccountManager.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract CreditEnforcerUnitTest2 is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    ERC1967Proxy proxy;

    Stablecoin rusd;
    Savingcoin srusd;

    Term term;
    TermIssuer termIssuer;

    SavingModule sm;
    PegStabilityModule psm;

    CreditEnforcer creditEnforcer;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        srusd = new Savingcoin(address(this), "Reservoir Savingcoin", "srUSD");

        term = new Term(address(this), "https://reservoir.io/terms/");

        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        psm.grantRole(psm.MANAGER(), address(this));

        rusd.grantRole(rusd.MINTER(), address(psm));

        termIssuer = new TermIssuer(
            address(this),
            91.25 days,
            0,
            ITerm(address(term)),
            IToken(address(rusd))
        );

        rusd.grantRole(rusd.MINTER(), address(termIssuer));
        term.grantRole(term.MINTER(), address(termIssuer));

        sm = new SavingModule(
            address(this),
            IToken(address(rusd)),
            IToken(address(srusd))
        );

        srusd.grantRole(srusd.MINTER(), address(this));
        rusd.grantRole(rusd.MINTER(), address(this));

        creditEnforcer = new CreditEnforcer(
            address(this),
            IERC20(address(usdc)),
            ITermIssuer(address(termIssuer)),
            IPegStabilityModule(address(psm)),
            ISavingModule(address(sm))
        );

        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));
        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));
        creditEnforcer.grantRole(creditEnforcer.SUPERVISOR(), address(this));

        creditEnforcer.setDuration(30 days);

        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setDuration(30 days);

        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);

        sm.grantRole(sm.CONTROLLER(), address(creditEnforcer));

        rusd.grantRole(rusd.MINTER(), address(sm));
        srusd.grantRole(srusd.MINTER(), address(sm));
    }

    function testMintSavingcoin(uint128 _amount) external {
        creditEnforcer.setSMDebtMax(type(uint256).max);

        rusd.mint(address(this), _amount);

        rusd.approve(address(sm), _amount);

        creditEnforcer.mintSavingcoin(_amount);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(srusd.balanceOf(address(this)), _amount);
    }

    function testMintSavingcoinWithTo(uint128 _amount, address to) external {
        vm.assume(to != address(0));

        creditEnforcer.setSMDebtMax(type(uint256).max);

        rusd.mint(address(this), _amount);

        rusd.approve(address(sm), _amount);

        creditEnforcer.mintSavingcoin(to, _amount);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(srusd.balanceOf(to), _amount);

        if (to != address(this)) {
            assertEq(srusd.balanceOf(address(this)), 0);
        }
    }

    function testMintSavingcoinMoreThanSMDebtMax(
        uint128 _amount,
        uint128 _smDebt
    ) external {
        vm.assume(_amount > 0);

        srusd.mint(address(1), _smDebt);

        creditEnforcer.setSMDebtMax((uint256(_amount) + uint256(_smDebt)) - 1);

        rusd.mint(address(this), _amount);

        rusd.approve(address(sm), _amount);

        vm.expectRevert("CE: amount exceeds SM debt max");
        creditEnforcer.mintSavingcoin(_amount);
    }

    function testMintSavingcoinAssetRatio(
        uint128 _amount,
        uint128 _psmValue,
        uint32 _assetRatioMin
    ) external {
        vm.assume(_amount > 0);
        vm.assume(_psmValue > 0);

        creditEnforcer.setSMDebtMax(type(uint256).max);
        creditEnforcer.setAssetRatioMin(_assetRatioMin);

        rusd.mint(address(this), _amount);
        usdc.mint(address(psm), _psmValue);

        rusd.approve(address(sm), _amount);

        if (
            (uint256(_psmValue) * 1e12 * 1e6) / uint256(_amount) >=
            _assetRatioMin
        ) {
            creditEnforcer.mintSavingcoin(_amount);
        } else {
            vm.expectRevert("CE: invalid asset ratio");
            creditEnforcer.mintSavingcoin(_amount);
        }
    }

    function testMintSavingcoinEquityRatio(
        uint128 _amount,
        uint128 _psmValue,
        uint32 _equityRatioMin,
        uint32 _psmRiskWeight
    ) external {
        vm.assume(_amount > 0);
        vm.assume(_psmValue > 0);
        vm.assume(_psmRiskWeight > 0 && _psmRiskWeight < 1e6);

        creditEnforcer.setSMDebtMax(type(uint256).max);
        creditEnforcer.setEquityRatioMin(_equityRatioMin);
        psm.setUnderlyingRiskWeight(_psmRiskWeight);

        rusd.mint(address(this), _amount);
        usdc.mint(address(psm), _psmValue);

        rusd.approve(address(sm), _amount);

        uint256 expectedAssets = uint256(_psmValue) * 1e12;
        uint256 expectedLiabilities = uint256(_amount);
        uint256 expectedEquity = expectedLiabilities > expectedAssets
            ? 0
            : expectedAssets - expectedLiabilities;
        uint256 expectedriskWeightedAssets = (uint256(_psmRiskWeight) *
            uint256(_psmValue) *
            1e12) / 1e6;

        if (
            (expectedEquity * 1e6) / expectedriskWeightedAssets >=
            _equityRatioMin
        ) {
            creditEnforcer.mintSavingcoin(_amount);
        } else {
            vm.expectRevert("CE: invalid equity ratio");
            creditEnforcer.mintSavingcoin(_amount);
        }
    }

    function testMintSavingcoinLiquidityRatio(
        uint128 _amount,
        uint128 _psmValue,
        uint32 _liquidityRatioMin
    ) external {
        vm.assume(_amount > 0);
        vm.assume(_psmValue > 0);

        creditEnforcer.setSMDebtMax(type(uint256).max);
        creditEnforcer.setLiquidityRatioMin(_liquidityRatioMin);

        rusd.mint(address(this), _amount);
        usdc.mint(address(psm), _psmValue);

        rusd.approve(address(sm), _amount);

        uint256 expectedShortTermAssets = uint256(_psmValue) * 1e12;
        uint256 expectedLiabilities = uint256(_amount);
        uint256 expectedExtendedLiabilities = 0;
        uint256 expectedShortTermLiabilities = expectedLiabilities -
            expectedExtendedLiabilities;

        if (
            (expectedShortTermAssets * 1e6) / expectedShortTermLiabilities >=
            _liquidityRatioMin
        ) {
            creditEnforcer.mintSavingcoin(_amount);
        } else {
            vm.expectRevert("CE: invalid liquidity ratio");
            creditEnforcer.mintSavingcoin(_amount);
        }
    }

    function testSetSMDebtMax(uint256 _smDebtMax) external {
        creditEnforcer.setSMDebtMax(_smDebtMax);
        assertEq(creditEnforcer.smDebtMax(), _smDebtMax);
    }

    function testSetSMDebtMaxUnauthorized(uint256 _smDebtMax) external {
        vm.expectRevert();
        vm.prank(eoa1);
        creditEnforcer.setSMDebtMax(_smDebtMax);
    }

    function testCheckSMDebtMax(
        uint128 smTotalDebt,
        uint128 _amount,
        uint32 smDebtMax
    ) external {
        srusd.mint(address(this), smTotalDebt);
        creditEnforcer.setSMDebtMax(smDebtMax);

        (bool valid, string memory message) = creditEnforcer.checkSMDebtMax(
            _amount
        );

        if (uint256(smTotalDebt) + uint256(_amount) > smDebtMax) {
            assertEq(valid, false);
            assertEq(message, "CE: amount exceeds SM debt max");
        } else {
            assertEq(valid, true);
            assertEq(message, "");
        }
    }
}
