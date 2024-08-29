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

contract AccountManagerFuzzTest is Test {
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

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);
    address eoa3 = vm.addr(3);
    address eoa4 = vm.addr(4);

    uint256 public constant BILLION_6_DECIMALS = 1_000_000_000e6;
    uint256 public constant BILLION_18_DECIMALS = 1_000_000_000e18;
    uint256 public constant MAX_COUPON_RATE = 1_000_000;

    uint256 public constant DELTA = 91.25 days;

    uint256[] public emptyArray;

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

        rusd.grantRole(rusd.MINTER(), address(psm));

        termIssuer = new TermIssuer(
            address(this),
            DELTA,
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

        creditEnforcer = new CreditEnforcer(
            address(this),
            IERC20(address(usdc)),
            ITermIssuer(address(termIssuer)),
            IPegStabilityModule(address(psm)),
            ISavingModule(address(sm))
        );

        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));

        creditEnforcer.setDuration(30 days);

        accountManager = new AccountManager(
            ICreditEnforcer(address(creditEnforcer)),
            0e6
        );

        creditEnforcer.setPSMDebtMax(type(uint256).max);

        creditEnforcer.setDuration(30 days);

        creditEnforcer.setAssetRatioMin(0);
        creditEnforcer.setEquityRatioMin(0);
        creditEnforcer.setLiquidityRatioMin(0);
    }

    function testInitialState() external {
        assertEq(address(accountManager.rusd()), address(rusd));
        assertEq(address(accountManager.term()), address(term));
        assertEq(address(accountManager.termIssuer()), address(termIssuer));
        assertEq(
            address(accountManager.creditEnforcer()),
            address(creditEnforcer)
        );
    }
}
