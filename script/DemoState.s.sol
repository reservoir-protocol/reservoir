// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MockFund} from "test/mocks/MockFund.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {AssetPrice, AssetAdapter} from "src/adapters/AssetAdapter.sol";

import {Term} from "src/Term.sol";
import {TermIssuer} from "src/TermIssuer.sol";
import {CreditEnforcer} from "src/CreditEnforcer.sol";
import {SavingModule} from "src/SavingModule.sol";
import {PegStabilityModule} from "src/PegStabilityModule.sol";
import {AccountManager} from "src/AccountManager.sol";

import {ITerm} from "src/interfaces/ITerm.sol";
import {ITermIssuer} from "src/interfaces/ITermIssuer.sol";
import {ICreditEnforcer} from "src/interfaces/ICreditEnforcer.sol";
import {ISavingModule} from "src/interfaces/ISavingModule.sol";
import {IPegStabilityModule} from "src/interfaces/IPegStabilityModule.sol";

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";

contract DemoStateScript is Script, Test {
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

    address[] private eoas;

    uint256 immutable START_DATE = vm.envUint("START_DATE");

    function setUp() external {
        eoas = [
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
            0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
            0x976EA74026E726554dB657fA54763abd0C3a0aa9,
            0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
            0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
            0xa0Ee7A142d267C1f36714E4a8F75612F20a79720,
            0xBcd4042DE499D14e55001CcbB24a551F3b954096,
            0x71bE63f3384f5fb98995898A86B02Fb2426c5788,
            0xFABB0ac9d68B0B445fB7357272Ff202C5651694a,
            0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec,
            0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097,
            0xcd3B766CCDd6AE721141F452C550Ca635964ce71,
            0x2546BcD3c84621e976D8185a91A922aE77ECEc30,
            0xbDA5747bFD65F08deb54cb465eB87D40e51B197E,
            0xdD2FD4581271e230360230F9337D5c0430Bf44C0,
            0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
        ];
    }

    function run() external {
        uint256 earliestID;

        vm.startBroadcast();

        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc.mint(eoas[1], 1_000_000e6);
        usdc.mint(eoas[2], 1_000_000e6);
        usdc.mint(eoas[3], 1_000_000e6);
        usdc.mint(eoas[4], 1_000_000e6);
        usdc.mint(eoas[5], 1_000_000e6);
        usdc.mint(eoas[6], 1_000_000e6);

        usdc.mint(msg.sender, 1_000_000e6);

        usdcAggregator = new MockV3Aggregator(8, 1e8);

        vm.stopBroadcast();

        console.log();
        console.log(" * USDC Address: %s", address(usdc));
        console.log(" = > constructor(string,string,uint256)");
        console.log(" - - >", "USD Coin Mock");
        console.log(" - - >", "USDC");
        console.log(" - - >", 6);

        console.log(
            " * USDC/USD Price Feed Address: %s",
            address(usdcAggregator)
        );
        console.log(" = > constructor(uint256,uint256)");
        console.log(" - - >", 8);
        console.log(" - - >", 1e8);

        vm.startBroadcast();

        rusd = new Stablecoin(msg.sender, "Reservoir Stablecoin", "rUSD");

        psm = new PegStabilityModule(
            msg.sender,
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        psm.grantRole(psm.MANAGER(), msg.sender);
        psm.grantRole(psm.SUPERVISOR(), msg.sender);
        rusd.grantRole(rusd.MINTER(), address(psm));

        usdc.approve(address(psm), type(uint256).max);

        psm.allocate(usdc.balanceOf(address(msg.sender)));

        vm.stopBroadcast();

        console.log();
        console.log(" * rUSD Address: %s", address(rusd));
        console.log(" = > constructor(address,string,string)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", "Reservoir Stablecoin");
        console.log(" - - >", "rUSD");

        assertEq(rusd.symbol(), "rUSD");
        assertEq(rusd.name(), "Reservoir Stablecoin");

        assertTrue(rusd.hasRole(rusd.MINTER(), address(psm)));
        assertTrue(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        console.log(" * Peg Stability Module Address: %s", address(psm));
        console.log(" = > constructor(address,address,address,address)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", address(usdcAggregator));
        console.log(" - - >", address(rusd));
        console.log(" - - >", address(usdc));

        assertTrue(psm.hasRole(psm.SUPERVISOR(), msg.sender));

        assertTrue(psm.hasRole(psm.MANAGER(), msg.sender));
        assertTrue(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertEq(address(psm.rusd()), address(rusd));
        assertEq(address(psm.underlying()), address(usdc));

        assertEq(address(psm.underlyingPriceOracle()), address(usdcAggregator));

        assertEq(psm.underlyingRiskWeight(), 0);
        assertEq(psm.DECIMAL_FACTOR(), 6);

        assertEq(psm.totalValue(), 1_000_000e18);
        assertEq(psm.underlyingBalance(), 1_000_000e6);

        assertEq(psm.underlyingTotalRiskValue(), 0e18);

        vm.startBroadcast();

        srusd = new Savingcoin(msg.sender, "Reservoir Savingcoin", "srUSD");

        sm = new SavingModule(
            msg.sender,
            IToken(address(rusd)),
            IToken(address(srusd))
        );

        sm.grantRole(sm.MANAGER(), msg.sender);

        rusd.grantRole(rusd.MINTER(), address(sm));
        srusd.grantRole(srusd.MINTER(), address(sm));

        vm.stopBroadcast();

        console.log();
        console.log(" * srUSD Address: %s", address(srusd));
        console.log(" = > constructor(address,string,string)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", "Reservoir Savingcoin");
        console.log(" - - >", "srUSD");

        assertEq(srusd.symbol(), "srUSD");
        assertEq(srusd.name(), "Reservoir Savingcoin");

        assertTrue(rusd.hasRole(rusd.MINTER(), address(sm)));

        assertTrue(srusd.hasRole(srusd.MINTER(), address(sm)));
        assertTrue(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        console.log(" * Saving Module Address: %s", address(sm));
        console.log(" = > constructor(address,address,address)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", address(rusd));
        console.log(" - - >", address(srusd));

        assertTrue(sm.hasRole(sm.MANAGER(), msg.sender));
        assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertEq(sm.lastTimestamp(), block.timestamp);

        assertEq(address(sm.rusd()), address(rusd));
        assertEq(address(sm.srusd()), address(srusd));

        assertEq(sm.currentRate(), 0e12);

        assertEq(sm.currentPrice(), 1e8);
        assertEq(sm.compoundFactor(), 1e8);

        vm.startBroadcast();

        term = new Term(msg.sender, "https://reservoir.io/terms/");
        termIssuer = new TermIssuer(
            msg.sender,
            91.25 days,
            START_DATE,
            ITerm(address(term)),
            IToken(address(rusd))
        );

        termIssuer.grantRole(termIssuer.MANAGER(), msg.sender);

        rusd.grantRole(rusd.MINTER(), address(termIssuer));
        term.grantRole(term.MINTER(), address(termIssuer));

        vm.stopBroadcast();

        console.log();
        console.log(" * Term Address: %s", address(term));
        console.log(" = > constructor(address,string,string)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", "https://reservoir.io/terms/");

        assertTrue(term.hasRole(term.DEFAULT_ADMIN_ROLE(), msg.sender));

        console.log(" * Term Issuer Address: %s", address(termIssuer));
        console.log(
            " = > constructor(address,uint256,uint256,uint256,address,address)"
        );
        console.log(" - - >", msg.sender);
        console.log(" - - >", 91.25 days);
        console.log(" - - >", 0);
        console.log(" - - >", address(term));
        console.log(" - - >", address(rusd));

        assertTrue(termIssuer.hasRole(termIssuer.MANAGER(), msg.sender));
        assertTrue(
            termIssuer.hasRole(termIssuer.DEFAULT_ADMIN_ROLE(), msg.sender)
        );

        assertTrue(rusd.hasRole(rusd.MINTER(), address(termIssuer)));
        assertTrue(term.hasRole(term.MINTER(), address(termIssuer)));

        assertEq(termIssuer.TERM_WINDOW(), 4);

        assertEq(termIssuer.DELTA(), 91.25 days);
        assertEq(termIssuer.GENESIS(), START_DATE);

        assertEq(address(termIssuer.rusd()), address(rusd));
        assertEq(address(termIssuer.term()), address(term));

        assertEq(termIssuer.totalDebt(), 0);

        earliestID = termIssuer.earliestID();

        vm.startBroadcast();

        _setDiscountRate(address(termIssuer), earliestID, 0.00006859294e12);
        _setDiscountRate(address(termIssuer), earliestID + 1, 0.00008221185e12);
        _setDiscountRate(address(termIssuer), earliestID + 2, 0.00009583227e12);
        _setDiscountRate(address(termIssuer), earliestID + 3, 0.00021675436e12);
        _setDiscountRate(address(termIssuer), earliestID + 4, 0.00021675436e12);

        vm.stopBroadcast();

        assertEq(termIssuer.getDiscountRate(earliestID), 0.00006859294e12);
        assertEq(termIssuer.getDiscountRate(earliestID + 1), 0.00008221185e12);
        assertEq(termIssuer.getDiscountRate(earliestID + 2), 0.00009583227e12);
        assertEq(termIssuer.getDiscountRate(earliestID + 3), 0.00021675436e12);
        assertEq(termIssuer.getDiscountRate(earliestID + 4), 0.00021675436e12);

        vm.startBroadcast();

        creditEnforcer = new CreditEnforcer(
            msg.sender,
            IERC20(address(usdc)),
            ITermIssuer(address(termIssuer)),
            IPegStabilityModule(address(psm)),
            ISavingModule(address(sm))
        );

        sm.grantRole(sm.CONTROLLER(), address(creditEnforcer));
        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), msg.sender);

        _setDuration(address(creditEnforcer), 30 days);

        _setAssetRationMin(address(creditEnforcer), 1.05e6);
        _setEquityRatioMin(address(creditEnforcer), 1.05e6);
        _setLiquidityRatioMin(address(creditEnforcer), 1.05e6);

        _setSMDebtMax(address(creditEnforcer), type(uint256).max);
        _setPSMDebtMax(address(creditEnforcer), type(uint256).max);

        _setTermDebtMax(address(creditEnforcer), earliestID, type(uint256).max);
        _setTermDebtMax(
            address(creditEnforcer),
            earliestID + 1,
            type(uint256).max
        );
        _setTermDebtMax(
            address(creditEnforcer),
            earliestID + 2,
            type(uint256).max
        );
        _setTermDebtMax(
            address(creditEnforcer),
            earliestID + 3,
            type(uint256).max
        );
        _setTermDebtMax(
            address(creditEnforcer),
            earliestID + 4,
            type(uint256).max
        );

        vm.stopBroadcast();

        console.log();
        console.log(" * Credit Enforcer Address: %s", address(creditEnforcer));
        console.log(
            " = > constructor(address,address,address,address,address)"
        );
        console.log(" - >", msg.sender);
        console.log(" - >", address(usdc));
        console.log(" - >", address(termIssuer));
        console.log(" - >", address(psm));
        console.log(" - >", address(sm));

        assertTrue(
            creditEnforcer.hasRole(creditEnforcer.MANAGER(), msg.sender)
        );
        assertTrue(
            creditEnforcer.hasRole(
                creditEnforcer.DEFAULT_ADMIN_ROLE(),
                msg.sender
            )
        );

        assertTrue(sm.hasRole(sm.CONTROLLER(), address(creditEnforcer)));
        assertTrue(psm.hasRole(psm.CONTROLLER(), address(creditEnforcer)));

        assertTrue(
            termIssuer.hasRole(termIssuer.CONTROLLER(), address(creditEnforcer))
        );

        assertEq(address(creditEnforcer.underlying()), address(usdc));
        assertEq(address(creditEnforcer.termIssuer()), address(termIssuer));

        assertEq(address(creditEnforcer.sm()), address(sm));
        assertEq(address(creditEnforcer.psm()), address(psm));

        assertEq(creditEnforcer.duration(), 30 days);

        assertEq(creditEnforcer.assetRatioMin(), 1.05e6);
        assertEq(creditEnforcer.equityRatioMin(), 1.05e6);
        assertEq(creditEnforcer.liquidityRatioMin(), 1.05e6);

        assertEq(creditEnforcer.smDebtMax(), type(uint256).max);
        assertEq(creditEnforcer.psmDebtMax(), type(uint256).max);

        assertEq(creditEnforcer.assetRatio(), type(uint256).max);
        assertEq(creditEnforcer.equityRatio(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatio(), type(uint256).max);

        vm.startBroadcast();

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0.08e12
        );

        vm.stopBroadcast();

        console.log();
        console.log(" * Account Manager Address: %s", address(accountManager));
        console.log(" = > constructor(address,address)");
        console.log(" - >", address(creditEnforcer));
        console.log(" - >", 0.08e12);

        assertEq(address(accountManager.rusd()), address(rusd));
        assertEq(address(accountManager.term()), address(term));

        assertEq(address(accountManager.termIssuer()), address(termIssuer));
        assertEq(
            address(accountManager.creditEnforcer()),
            address(creditEnforcer)
        );

        assertEq(accountManager.couponRate(), 0.08e12);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                     C R E D I T - E N F O R C E R                     *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function setDuration(address ca, uint256 duration) external {
        vm.startBroadcast();

        _setDuration(ca, duration);

        vm.stopBroadcast();
    }

    function _setDuration(address ca, uint256 duration) private {
        CreditEnforcer(ca).setDuration(duration);
    }

    function setAssetRationMin(address ca, uint256 assetRatioMin) external {
        vm.startBroadcast();

        _setAssetRationMin(ca, assetRatioMin);

        vm.stopBroadcast();
    }

    function _setAssetRationMin(address ce, uint256 assetRatioMin) private {
        CreditEnforcer(ce).setAssetRatioMin(assetRatioMin);
    }

    function setEquityRatioMin(address ca, uint256 equityRatioMin) external {
        vm.startBroadcast();

        _setEquityRatioMin(ca, equityRatioMin);

        vm.stopBroadcast();
    }

    function _setEquityRatioMin(address ca, uint256 equityRatioMin) private {
        CreditEnforcer(ca).setEquityRatioMin(equityRatioMin);
    }

    function setLiquidityRatioMin(address ca, uint256 ratio) external {
        vm.startBroadcast();

        _setLiquidityRatioMin(ca, ratio);

        vm.stopBroadcast();
    }

    function _setLiquidityRatioMin(address ce, uint256 ratio) private {
        CreditEnforcer(ce).setLiquidityRatioMin(ratio);
    }

    function setSMDebtMax(address ca, uint256 amount) external {
        vm.startBroadcast();

        _setSMDebtMax(ca, amount);

        vm.stopBroadcast();
    }

    function _setSMDebtMax(address ca, uint256 amount) private {
        CreditEnforcer(ca).setSMDebtMax(amount);
    }

    function setPSMDebtMax(address ca, uint256 amount) external {
        vm.startBroadcast();

        _setPSMDebtMax(ca, amount);

        vm.stopBroadcast();
    }

    function _setPSMDebtMax(address ca, uint256 amount) private {
        CreditEnforcer(ca).setPSMDebtMax(amount);
    }

    function setTermDebtMax(
        address ca,
        uint256 index,
        uint256 amount
    ) external {
        vm.startBroadcast();

        _setTermDebtMax(ca, index, amount);

        vm.stopBroadcast();
    }

    function _setTermDebtMax(
        address ca,
        uint256 index,
        uint256 amount
    ) private {
        CreditEnforcer(ca).setTermDebtMax(index, amount);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                P E G - S T A B I L I T Y - M O D U L E                *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function setUSDCRiskWeight(address ca, uint256 amount) external {
        vm.startBroadcast();

        _setUSDCRiskWeight(ca, amount);

        vm.stopBroadcast();
    }

    function _setUSDCRiskWeight(address ca, uint256 amount) private {
        PegStabilityModule(ca).setUnderlyingRiskWeight(amount);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                       S A V I N G - M O D U L E                       *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function update(address ca, uint256 amount) external {
        vm.startBroadcast();

        _update(ca, amount);

        vm.stopBroadcast();
    }

    function _update(address ca, uint256 amount) private {
        SavingModule(ca).update(amount);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                         T E R M - I S S U E R                         *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function setDiscountRate(address ca, uint256 index, uint256 rate) external {
        vm.startBroadcast();

        _setDiscountRate(ca, index, rate);

        vm.stopBroadcast();
    }

    function _setDiscountRate(address ca, uint256 index, uint256 rate) private {
        TermIssuer(ca).setDiscountRate(index, rate);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                        F U N D - A D A P T E R                        *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function addAssetAdapter(address ca, address adapter) external {
        vm.startBroadcast();

        _addAssetAdapter(ca, adapter);

        vm.stopBroadcast();
    }

    function _addAssetAdapter(address ca, address adapter) private {
        CreditEnforcer(ca).addAssetAdapter(adapter);
    }

    function removeAssetAdapter(address ca, address assetAdapter) external {
        vm.startBroadcast();

        _removeAssetAdapter(ca, assetAdapter);

        vm.stopBroadcast();
    }

    function _removeAssetAdapter(address ca, address assetAdapter) private {
        CreditEnforcer(ca).removeAssetAdapter(assetAdapter);
    }

    function deployAssetAdapter(
        address usdc_,
        address fund,
        address usdcAggregator_,
        uint256 duration
    ) external {
        address assetAdapterAddr;
        address fundPriceOracleAddr;

        vm.startBroadcast();

        (fundPriceOracleAddr, assetAdapterAddr) = _deployAssetAdapter(
            usdc_,
            fund,
            usdcAggregator_,
            duration
        );

        vm.stopBroadcast();

        console.log();
        console.log(" * Fund Price Oracle Address: %s", fundPriceOracleAddr);
        console.log(" = > constructor(address)");
        console.log(" - - >", address(fund));

        console.log();
        console.log(" * Asset Adapter Address: %s", assetAdapterAddr);
        console.log(
            " = > constructor(address,address,address,address,address,uint256)"
        );
        console.log(" - - >", msg.sender);
        console.log(" - - >", usdc_);
        console.log(" - - >", fund);
        console.log(" - - >", usdcAggregator_);
        console.log(" - - >", fundPriceOracleAddr);
        console.log(" - - >", duration);
    }

    function _deployAssetAdapter(
        address usdc_,
        address fund,
        address usdcAggregator_,
        uint256 duration
    ) private returns (address, address) {
        AssetPrice fundPriceOracle = new AssetPrice(fund);

        AssetAdapter assetAdapter = new AssetAdapter(
            msg.sender,
            usdc_,
            fund,
            usdcAggregator_,
            address(fundPriceOracle),
            duration
        );

        return (address(fundPriceOracle), address(assetAdapter));
    }

    // NOTE: Real fund must be deployed in script to mainnet

    function deployMockFund(string memory name, string memory symbol) external {
        address mockFundAddr;

        vm.startBroadcast();

        mockFundAddr = _deployMockFund(name, symbol);

        vm.stopBroadcast();

        console.log();
        console.log(" * Mock Fund Address: %s", mockFundAddr);
        console.log(" = > constructor(string,string,uint256)");
        console.log(" - - >", name);
        console.log(" - - >", symbol);
        console.log(" - - >", 18);
    }

    function _deployMockFund(
        string memory name,
        string memory symbol
    ) private returns (address) {
        MockFund mockFund = new MockFund(name, symbol, 18);

        return address(mockFund);
    }

    function setMockFundTotalValue(address ca, uint256 amount) external {
        vm.startBroadcast();

        _setMockFundTotalValue(ca, amount);

        vm.stopBroadcast();
    }

    function _setMockFundTotalValue(address ca, uint256 amount) private {
        MockFund(ca).setTotalValue(amount);
    }

    function setMockFundTotalRiskValue(address fa, uint256 amount) external {
        vm.startBroadcast();

        _setMockFundTotalRiskValue(fa, amount);

        vm.stopBroadcast();
    }

    function _setMockFundTotalRiskValue(address ca, uint256 amount) private {
        MockFund(ca).setTotalValue(amount);
    }
}
