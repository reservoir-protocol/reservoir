// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {OffchainFund} from "offchain-fund/src/OffchainFund.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {AssetPrice, AssetAdapter} from "src/adapters/AssetAdapter.sol";
import {MorphoUnderlyingAdapter} from "src/adapters/MorphoUnderlyingAdapter.sol";
import {VaultSharesOracle} from "src/adapters/VaultSharesOracle.sol";

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

contract ReservoirScript is Script, Test {
    IERC20 usdc;
    AggregatorV3Interface usdcAggregator;

    Stablecoin rusd;
    Savingcoin srusd;

    Term term;
    TermIssuer termIssuer;

    SavingModule sm;
    PegStabilityModule psm;

    CreditEnforcer creditEnforcer;
    AccountManager accountManager;

    address immutable ADMIN = vm.envAddress("ADMIN");
    uint256 immutable START_DATE = vm.envUint("START_DATE");

    function setUp() external {}

    function run() external {
        usdc = IERC20(vm.envAddress("USDC_ADDRESS"));

        usdcAggregator = AggregatorV3Interface(
            vm.envAddress("USDC_AGGREGATOR_ADDRESS")
        );

        vm.startBroadcast();

        rusd = Stablecoin(0x09d4214c03d01f49544c0448dbe3a27f768f2b34);

        psm = PegStabilityModule(0x4809010926aec940b550d34a46a52739f996d75d);

        // rusd.grantRole(rusd.MINTER(), address(psm));

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

        assertTrue(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertEq(address(psm.rusd()), address(rusd));
        assertEq(address(psm.underlying()), address(usdc));

        assertEq(address(psm.underlyingPriceOracle()), address(usdcAggregator));

        assertEq(psm.DECIMAL_FACTOR(), 6);

        assertEq(psm.underlyingBalance(), 0e6);
        assertEq(psm.underlyingRiskWeight(), 0e6);

        assertEq(psm.totalValue(), 0e18);
        assertEq(psm.underlyingTotalRiskValue(), 0e18);

        vm.startBroadcast();

        srusd = Savingcoin(0x738d1115b90efa71ae468f1287fc864775e23a31);

        sm = SavingModule(0x5475611dffb8ef4d697ae39df9395513b6e947d7);

        // rusd.grantRole(rusd.MINTER(), address(sm));
        // srusd.grantRole(srusd.MINTER(), address(sm));

        vm.stopBroadcast();

        console.log();
        console.log(" * srUSD Address: %s", address(srusd));
        console.log(" = > constructor(address,string,string)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", "Savings rUSD");
        console.log(" - - >", "srUSD");

        assertEq(srusd.symbol(), "srUSD");
        assertEq(srusd.name(), "Savings rUSD");

        assertTrue(rusd.hasRole(rusd.MINTER(), address(sm)));
        assertTrue(srusd.hasRole(srusd.MINTER(), address(sm)));

        assertTrue(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        console.log(" * Saving Module Address: %s", address(sm));
        console.log(" = > constructor(address,address,address)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", address(rusd));
        console.log(" - - >", address(srusd));

        assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertEq(sm.lastTimestamp(), block.timestamp);

        assertEq(address(sm.rusd()), address(rusd));
        assertEq(address(sm.srusd()), address(srusd));

        assertEq(sm.currentRate(), 0e12);

        assertEq(sm.currentPrice(), 1e8);
        assertEq(sm.compoundFactor(), 1e8);

        vm.startBroadcast();

        term = Term(0x6c19e25bd34d063829dd05e2a5fae165ddf2c8dd);
        termIssuer = TermIssuer(0x128d86a9e854a709df06b884f81eee7240f6ccf7);

        // rusd.grantRole(rusd.MINTER(), address(termIssuer));
        // term.grantRole(term.MINTER(), address(termIssuer));

        vm.stopBroadcast();

        console.log();
        console.log(" * Term Address: %s", address(term));
        console.log(" = > constructor(address,string,string)");
        console.log(" - - >", msg.sender);
        console.log(" - - >", "https://reservoir.xyz");

        assertTrue(term.hasRole(term.DEFAULT_ADMIN_ROLE(), msg.sender));

        console.log(" * Term Issuer Address: %s", address(termIssuer));
        console.log(
            " = > constructor(address,uint256,uint256,uint256,address,address)"
        );
        console.log(" - - >", msg.sender);
        console.log(" - - >", 91.25 days);
        console.log(" - - >", START_DATE);
        console.log(" - - >", address(term));
        console.log(" - - >", address(rusd));

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

        assertEq(creditEnforcer.duration(), 365 days);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.smDebtMax(), 0);
        assertEq(creditEnforcer.psmDebtMax(), 0);

        assertEq(creditEnforcer.assetRatio(), 0);
        assertEq(creditEnforcer.equityRatio(), 0);
        assertEq(creditEnforcer.liquidityRatio(), 0);

        // vm.startBroadcast();

        // accountManager = new AccountManager(
        //     ICreditEnforcer(address(creditEnforcer)),
        //     0.08e12
        // );

        // vm.stopBroadcast();

        // console.log();
        // console.log(" * Account Manager Address: %s", address(accountManager));
        // console.log(" = > constructor(address,address)");
        // console.log(" - >", address(creditEnforcer));
        // console.log(" - >", 0.08e12);

        // assertEq(address(accountManager.rusd()), address(rusd));
        // assertEq(address(accountManager.term()), address(term));

        // assertEq(address(accountManager.termIssuer()), address(termIssuer));
        // assertEq(
        //     address(accountManager.creditEnforcer()),
        //     address(creditEnforcer)
        // );

        // assertEq(accountManager.couponRate(), 0.08e12);

        // assertFalse(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertFalse(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertFalse(term.hasRole(term.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(term.hasRole(term.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertFalse(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertFalse(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertFalse(termIssuer.hasRole(sm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertTrue(termIssuer.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertFalse(creditEnforcer.hasRole(psm.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(
            creditEnforcer.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender)
        );

        vm.startBroadcast();

        // rusd.grantRole(rusd.DEFAULT_ADMIN_ROLE(), ADMIN);
        // rusd.revokeRole(rusd.DEFAULT_ADMIN_ROLE(), msg.sender);

        // srusd.grantRole(srusd.DEFAULT_ADMIN_ROLE(), ADMIN);
        // srusd.revokeRole(srusd.DEFAULT_ADMIN_ROLE(), msg.sender);

        // term.grantRole(term.DEFAULT_ADMIN_ROLE(), ADMIN);
        // term.revokeRole(term.DEFAULT_ADMIN_ROLE(), msg.sender);

        // sm.grantRole(sm.DEFAULT_ADMIN_ROLE(), ADMIN);
        // sm.revokeRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender);

        // psm.grantRole(psm.DEFAULT_ADMIN_ROLE(), ADMIN);
        // psm.revokeRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender);

        // termIssuer.grantRole(termIssuer.DEFAULT_ADMIN_ROLE(), ADMIN);
        // termIssuer.revokeRole(termIssuer.DEFAULT_ADMIN_ROLE(), msg.sender);

        creditEnforcer.grantRole(creditEnforcer.DEFAULT_ADMIN_ROLE(), ADMIN);
        creditEnforcer.revokeRole(
            creditEnforcer.DEFAULT_ADMIN_ROLE(),
            msg.sender
        );

        vm.stopBroadcast();

        // assertTrue(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(rusd.hasRole(rusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertTrue(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(srusd.hasRole(srusd.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertTrue(term.hasRole(term.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(term.hasRole(term.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertTrue(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender));

        // assertTrue(termIssuer.hasRole(sm.DEFAULT_ADMIN_ROLE(), ADMIN));
        // assertFalse(termIssuer.hasRole(sm.DEFAULT_ADMIN_ROLE(), msg.sender));

        assertTrue(creditEnforcer.hasRole(psm.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertFalse(
            creditEnforcer.hasRole(psm.DEFAULT_ADMIN_ROLE(), msg.sender)
        );
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
        address admin,
        address usdc_,
        address fund,
        address usdcAggregator_,
        uint256 duration
    ) external {
        address assetAdapterAddr;
        address fundPriceOracleAddr;

        vm.startBroadcast();

        (fundPriceOracleAddr, assetAdapterAddr) = _deployAssetAdapter(
            admin,
            usdc_,
            fund,
            usdcAggregator_,
            duration
        );

        vm.stopBroadcast();

        console.log();
        console.log(" * Fund/USD Price Feed Address: %s", fundPriceOracleAddr);
        console.log(" = > constructor(address)");
        console.log(" - - >", address(fund));

        console.log();
        console.log(" * Asset Adapter Address: %s", assetAdapterAddr);
        console.log(
            " = > constructor(address,address,address,address,address,uint256)"
        );
        console.log(" - - >", admin);
        console.log(" - - >", usdc_);
        console.log(" - - >", fund);
        console.log(" - - >", usdcAggregator_);
        console.log(" - - >", fundPriceOracleAddr);
        console.log(" - - >", duration);
    }

    function _deployAssetAdapter(
        address admin,
        address usdc_,
        address fund,
        address usdcAggregator_,
        uint256 duration
    ) private returns (address, address) {
        AssetPrice fundPriceOracle = new AssetPrice(fund);

        AssetAdapter assetAdapter = new AssetAdapter(
            admin,
            usdc_,
            fund,
            usdcAggregator_,
            address(fundPriceOracle),
            duration
        );

        return (address(fundPriceOracle), address(assetAdapter));
    }

    function deployFund(
        address owner,
        address usdc_,
        string memory name,
        string memory symbol
    ) external {
        address fundAddr;

        vm.startBroadcast();

        fundAddr = _deployFund(owner, usdc_, name, symbol);

        vm.stopBroadcast();

        console.log();
        console.log(" * Offchain Fund Address: %s", fundAddr);
        console.log(" = > constructor(address,address,string,string)");
        console.log(" - - >", owner);
        console.log(" - - >", usdc_);
        console.log(" - - >", name);
        console.log(" - - >", symbol);
    }

    function _deployFund(
        address owner,
        address usdc_,
        string memory name,
        string memory symbol
    ) private returns (address) {
        OffchainFund offchainFund = new OffchainFund(
            owner,
            usdc_,
            name,
            symbol
        );

        return address(offchainFund);
    }

    /** * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **
     *                     M O R P H O - A D A P T E R                       *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function addMorphoUnderlyingAdapter(
        address ca,
        address morphoUnderlyingAdapter
    ) external {
        vm.startBroadcast();

        _addMorphoUnderlyingAdapter(ca, morphoUnderlyingAdapter);

        vm.stopBroadcast();
    }

    function _addMorphoUnderlyingAdapter(
        address ca,
        address morphoUnderlyingAdapter
    ) private {
        CreditEnforcer(ca).addAssetAdapter(morphoUnderlyingAdapter);
    }

    function removeMorphoUnderlyingAdapter(
        address ca,
        address morphoUnderlyingAdapter
    ) external {
        vm.startBroadcast();

        _removeMorphoUnderlyingAdapter(ca, morphoUnderlyingAdapter);

        vm.stopBroadcast();
    }

    function _removeMorphoUnderlyingAdapter(
        address ca,
        address morphoUnderlyingAdapter
    ) private {
        CreditEnforcer(ca).removeAssetAdapter(morphoUnderlyingAdapter);
    }

    function deployMorphoUnderlyingAdapter(
        address _admin,
        address _underlying,
        address _vault,
        address _underlyingAggregator,
        uint256 _duration
    ) external {
        address morphoUnderlyingAdapterAddr;
        address fundPriceOracleAddr;

        vm.startBroadcast();

        (
            fundPriceOracleAddr,
            morphoUnderlyingAdapterAddr
        ) = _deployMorphoUnderlyingAdapter(
            _admin,
            _underlying,
            _vault,
            _underlyingAggregator,
            _duration
        );

        vm.stopBroadcast();

        console.log();
        console.log(
            " * VaultShare/USD Price Feed Address: %s",
            fundPriceOracleAddr
        );
        console.log(" = > constructor(address)");
        console.log(" - - >", address(_vault));

        console.log();
        console.log(
            " * Morpho Underlying Adapter Address: %s",
            morphoUnderlyingAdapterAddr
        );
        console.log(
            " = > constructor(address,address,address,address,address,uint256)"
        );
        console.log(" - - >", _admin);
        console.log(" - - >", _underlying);
        console.log(" - - >", _vault);
        console.log(" - - >", _underlyingAggregator);
        console.log(" - - >", fundPriceOracleAddr);
        console.log(" - - >", _duration);
    }

    function _deployMorphoUnderlyingAdapter(
        address _admin,
        address _underlying,
        address _vault,
        address _underlyingAggregator,
        uint256 _duration
    ) private returns (address, address) {
        VaultSharesOracle vaultSharesOracle = new VaultSharesOracle(
            AggregatorV3Interface(_underlyingAggregator),
            IERC4626(_vault)
        );

        MorphoUnderlyingAdapter morphoUnderlyingAdapter = new MorphoUnderlyingAdapter(
                _admin,
                _underlying,
                _vault,
                _underlyingAggregator,
                address(vaultSharesOracle),
                _duration
            );

        return (address(vaultSharesOracle), address(morphoUnderlyingAdapter));
    }
}
