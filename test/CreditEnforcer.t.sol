// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {ITerm, Term} from "src/Term.sol";
import {ITermIssuer, TermIssuer} from "src/TermIssuer.sol";

import {ISavingModule, SavingModule} from "src/SavingModule.sol";
import {IPegStabilityModule, PegStabilityModule} from "src/PegStabilityModule.sol";

import {AssetPrice, IAssetAdapter, AssetAdapter} from "src/adapters/AssetAdapter.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {CreditEnforcer} from "src/CreditEnforcer.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract MockFund is ERC20DecimalsMock {
    event Deposit(address, uint256);

    event Redemption(address, uint256);

    uint256 public totalDeposits;
    uint256 public totalRedemptions;

    uint256 public currentPrice;

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userRedemptions;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20DecimalsMock(name_, symbol_, decimals_) {}

    function deposit(uint256 amount) external {
        userDeposits[msg.sender] += amount;

        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    function redeem(uint256 amount) external {
        userRedemptions[msg.sender] += amount;

        totalRedemptions += amount;

        emit Redemption(msg.sender, amount);
    }

    function updatePrice(uint256 price) external {
        currentPrice = price;
    }
}

contract CreditEnforcerTest is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

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

        usdc.mint(eoa1, 10_000_000e6);
        usdc.mint(eoa2, 10_000_000e6);

        usdc.mint(address(this), 10_000_000e6);

        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        srusd = new Savingcoin(address(this), "Savings rUSD", "srUSD");

        term = new Term(address(this), "https://reservoir.xyz");

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
            91.25 days,
            0,
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

        sm.grantRole(sm.CONTROLLER(), address(creditEnforcer));
        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));
        creditEnforcer.grantRole(creditEnforcer.SUPERVISOR(), address(this));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        // = = =

        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        // TODO: Fix this, set new rates

        termIssuer.setDiscountRate(1, 0.000210874000e12);
        termIssuer.setDiscountRate(3, 0.000210874000e12);

        // termIssuer.setDiscountRate(1, 0.00006859294e12);
        // termIssuer.setDiscountRate(2, 0.00008217862e12);
        // termIssuer.setDiscountRate(3, 0.00009574398e12);

        creditEnforcer.setDuration(30 days);

        vm.prank(eoa1);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(psm), type(uint256).max);

        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa1);
        rusd.approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(termIssuer), type(uint256).max);

        rusd.approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa1);
        term.setApprovalForAll(address(termIssuer), true);

        vm.prank(eoa2);
        term.setApprovalForAll(address(termIssuer), true);

        term.setApprovalForAll(address(termIssuer), true);
    }

    function testAssetRatio() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        assertEq(creditEnforcer.assetRatio(), 0); // 0%

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.liabilities(), 0);

        psm.allocate(100_000e6);
        assertEq(creditEnforcer.assetRatio(), type(uint256).max); //
        assertEq(creditEnforcer.assets(), 100_000e18);
        assertEq(creditEnforcer.liabilities(), 0);

        creditEnforcer.mintStablecoin(100_000e6);
        assertEq(creditEnforcer.assetRatio(), 2_000_000); // 200%

        assertEq(creditEnforcer.assets(), 200_000e18);
        assertEq(creditEnforcer.liabilities(), 100_000e18);

        creditEnforcer.mintStablecoin(100_000e6);
        assertEq(creditEnforcer.assetRatio(), 1_500_000); // 150%

        assertEq(creditEnforcer.assets(), 300_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);

        MockFund mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        AssetPrice assetPrice = new AssetPrice(address(mockFund));

        AssetAdapter assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        creditEnforcer.addAssetAdapter(address(assetAdapter));

        // TODO: Mock Asset Adapter

        bytes memory encodedSelector;

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalValue.selector
        );

        vm.mockCall(
            address(assetAdapter),
            encodedSelector,
            abi.encode(100_000e18)
        );

        assertEq(creditEnforcer.assetRatio(), 2_000_000); // 200%

        assertEq(creditEnforcer.assets(), 400_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);
    }

    function testEquityRatio() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        assertEq(creditEnforcer.equityRatio(), 0); // 0%

        assertEq(creditEnforcer.equity(), 0);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        psm.allocate(100_000e6);
        assertEq(creditEnforcer.equityRatio(), type(uint256).max); //
        assertEq(creditEnforcer.equity(), 100_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        creditEnforcer.mintStablecoin(100_000e6);
        assertEq(creditEnforcer.equityRatio(), type(uint256).max); //
        assertEq(creditEnforcer.equity(), 100_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        MockFund mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        AssetPrice assetPrice = new AssetPrice(address(mockFund));

        AssetAdapter assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        creditEnforcer.addAssetAdapter(address(assetAdapter));

        // TODO: Mock Asset Adapter

        bytes memory encodedSelector;

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalValue.selector
        );

        vm.mockCall(
            address(assetAdapter),
            encodedSelector,
            abi.encode(100_000e18)
        );

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalRiskValue.selector
        );

        vm.mockCall(address(assetAdapter), encodedSelector, abi.encode(0));

        // tinlakeAdapter.setTotalValue(100_000e18);
        assertEq(creditEnforcer.equityRatio(), type(uint256).max); //
        assertEq(creditEnforcer.equity(), 200_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        vm.mockCall(
            address(assetAdapter),
            encodedSelector,
            abi.encode(100_000e18)
        );

        // tinlakeAdapter.setRiskValue(100_000e18);
        assertEq(creditEnforcer.equityRatio(), 2_000_000); // 200%

        assertEq(creditEnforcer.equity(), 200_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 100_000e18);
    }

    function testLiquidityRatio() external {
        creditEnforcer.setPSMDebtMax(type(uint256).max);
        creditEnforcer.setTermDebtMax(3, type(uint256).max);

        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        uint256 pv;
        uint256 mTimestamp;
        uint256 discountRate;

        assertEq(creditEnforcer.liquidityRatio(), 0); // 0%

        assertEq(creditEnforcer.shortTermAssets(), 0);
        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        psm.allocate(100_000e6);
        assertEq(creditEnforcer.liquidityRatio(), type(uint256).max); //
        assertEq(creditEnforcer.shortTermAssets(), 100_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        assertEq(creditEnforcer.liquidityRatio(), 2_000_000); // 200.0%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        vm.prank(eoa1);
        creditEnforcer.mintTerm(3, 100_000e18);

        mTimestamp = termIssuer.maturityTimestamp(3);
        discountRate = termIssuer.getDiscountRate(3);
        pv = termIssuer.applyDiscount(100_000e18, mTimestamp, discountRate);

        assertEq(rusd.balanceOf(eoa1), 100_000e18 - pv);
        assertEq(creditEnforcer.liquidityRatio(), 35_754_673); // 3,575.5%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), rusd.totalSupply());

        skip(120 days);
        assertEq(creditEnforcer.liquidityRatio(), 35_754_673); // 3,575.5%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), rusd.totalSupply());

        skip(120 days);
        assertEq(creditEnforcer.liquidityRatio(), 35_754_673); // 3,575.5%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), rusd.totalSupply());

        skip(60 days);
        assertEq(creditEnforcer.liquidityRatio(), 1_894_052); // 189.4%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(
            creditEnforcer.shortTermLiabilities(),
            rusd.totalSupply() + 100_000e18
        );

        vm.prank(eoa1);
        termIssuer.redeem(3, 100_000e18);

        assertEq(creditEnforcer.liquidityRatio(), 1_894_052); // 189.4%

        assertEq(creditEnforcer.shortTermAssets(), 200_000e18);
        assertEq(creditEnforcer.shortTermLiabilities(), rusd.totalSupply());
    }

    function testTransfers() external {
        psm.allocate(300_000e6);

        assertEq(psm.underlyingBalance(), 300_000e6);
        // assertEq(usdc.balanceOf(address(tinlakeAdapter)), 0);

        vm.expectRevert();
        creditEnforcer.allocate(0, 400_000e6);

        // TODO: Mock Asset Adapter

        MockFund mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        AssetPrice assetPrice = new AssetPrice(address(mockFund));

        AssetAdapter assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        assetAdapter.grantRole(
            assetAdapter.CONTROLLER(),
            address(creditEnforcer)
        );

        creditEnforcer.addAssetAdapter(address(assetAdapter));

        creditEnforcer.allocate(0, 100_000e6);

        assertEq(psm.underlyingBalance(), 200_000e6);
        assertEq(usdc.balanceOf(address(assetAdapter)), 100_000e6);

        vm.expectRevert();
        creditEnforcer.withdraw(0, 200_000e6);

        creditEnforcer.withdraw(0, 100_000e6);

        assertEq(psm.underlyingBalance(), 300_000e6);
        assertEq(usdc.balanceOf(address(assetAdapter)), 0);
    }

    function testInvalidMint() external {
        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(1e6);

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        creditEnforcer.setPSMDebtMax(100_000e6);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 100_000e6);

        psm.allocate(100_000e6);

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        creditEnforcer.setPSMDebtMax(200_000e6);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 100_000e6);

        // TODO: Mock Asset Adapter

        MockFund mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        AssetPrice assetPrice = new AssetPrice(address(mockFund));

        AssetAdapter assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        creditEnforcer.addAssetAdapter(address(assetAdapter));

        bytes memory encodedSelector;

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalValue.selector
        );

        vm.mockCall(address(assetAdapter), encodedSelector, abi.encode(0));

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalRiskValue.selector
        );

        vm.mockCall(
            address(assetAdapter),
            encodedSelector,
            abi.encode(100_000e18)
        );

        creditEnforcer.setAssetRatioMin(0);
        // tinlakeAdapter.setRiskValue(100_000e18);

        // QUESTION: Infinite equty ratio when capital at risk is zero?

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 100_000e6);

        creditEnforcer.setEquityRatioMin(0e6);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 100_000e6);
    }

    function testSuccessfulMint() external {
        assertEq(rusd.balanceOf(eoa1), 0);
        assertEq(rusd.balanceOf(eoa2), 0);

        assertEq(usdc.balanceOf(eoa1), 10_000_000e6);
        assertEq(usdc.balanceOf(eoa2), 10_000_000e6);

        psm.allocate(100_000e6);
        creditEnforcer.setPSMDebtMax(300_000e6);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 100_000e6);

        assertEq(rusd.balanceOf(eoa1), 100_000e18);
        assertEq(rusd.balanceOf(eoa2), 100_000e18);

        assertEq(usdc.balanceOf(eoa1), 9_800_000e6);
        assertEq(usdc.balanceOf(eoa2), 10_000_000e6);
    }

    function testInvalidIssue() external {
        assertEq(creditEnforcer.assetRatio(), 0);
        assertEq(creditEnforcer.equityRatio(), 0);
        assertEq(creditEnforcer.liquidityRatio(), 0);

        psm.allocate(100_000e6);
        creditEnforcer.setPSMDebtMax(200_000e6);

        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        creditEnforcer.setAssetRatioMin(type(uint256).max);
        creditEnforcer.setEquityRatioMin(type(uint256).max);
        creditEnforcer.setLiquidityRatioMin(type(uint256).max);

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);

        creditEnforcer.setTermDebtMax(1, 100_000e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);

        // TODO: Mock Asset Adapter

        MockFund mockFund = new MockFund("Offchain Fund Mock", "FUND", 18);
        AssetPrice assetPrice = new AssetPrice(address(mockFund));

        AssetAdapter assetAdapter = new AssetAdapter(
            address(this),
            address(usdc),
            address(mockFund),
            address(usdcAggregator),
            address(assetPrice),
            30 days
        );

        creditEnforcer.addAssetAdapter(address(assetAdapter));

        bytes memory encodedSelector;

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalValue.selector
        );

        vm.mockCall(address(assetAdapter), encodedSelector, abi.encode(0));

        encodedSelector = abi.encodeWithSelector(
            IAssetAdapter.totalRiskValue.selector
        );

        vm.mockCall(
            address(assetAdapter),
            encodedSelector,
            abi.encode(100_000e18)
        );

        creditEnforcer.setAssetRatioMin(0e6);
        // tinlakeAdapter.setRiskValue(100_000e18);

        // QUESTION: Infinite equty ratio when capital at risk is zero?

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);

        creditEnforcer.setEquityRatioMin(0e6);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);

        creditEnforcer.setTermDebtMax(1, 0.000000000000000001e18);

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);
    }

    function testSuccessfulIssue() external {
        uint256 pv;
        uint256 mTimestamp;
        uint256 discountRate;

        assertEq(rusd.balanceOf(eoa1), 0);
        assertEq(rusd.balanceOf(eoa2), 0);

        assertEq(term.balanceOf(eoa1, 1), 0);
        assertEq(term.balanceOf(eoa2, 1), 0);

        psm.allocate(100_000e6);

        creditEnforcer.setPSMDebtMax(300_000e6);
        creditEnforcer.setTermDebtMax(1, 200_000e18);

        creditEnforcer.setAssetRatioMin(0e6);
        creditEnforcer.setEquityRatioMin(0e6);
        creditEnforcer.setLiquidityRatioMin(0e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(200_000e6);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintTerm(1, 100_000e18);

        vm.prank(eoa1);
        creditEnforcer.mintTerm(eoa2, 1, 100_000e18);

        mTimestamp = termIssuer.maturityTimestamp(1);
        discountRate = termIssuer.getDiscountRate(1);

        pv = termIssuer.applyDiscount(200_000e18, mTimestamp, discountRate);

        assertEq(rusd.balanceOf(eoa2), 0);
        assertEq(rusd.balanceOf(eoa1), 200_000e18 - pv + 1); // NOTE: Small rounding offset

        assertEq(term.balanceOf(eoa1, 1), 100_000e18);
        assertEq(term.balanceOf(eoa2, 1), 100_000e18);
    }

    function testDeposit() external {
        assertEq(rusd.balanceOf(eoa1), 0);
        assertEq(rusd.balanceOf(eoa2), 0);

        assertEq(usdc.balanceOf(eoa1), 10_000_000e6);
        assertEq(usdc.balanceOf(eoa2), 10_000_000e6);

        psm.allocate(100_000e6);
        creditEnforcer.setPSMDebtMax(300_000e6);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(100_000e6);

        // set up the mock tinlake adapter

        // call deposit
    }
}
