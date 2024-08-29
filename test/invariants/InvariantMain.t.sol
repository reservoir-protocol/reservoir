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

import "forge-std/InvariantTest.sol";

contract InvariantMainTest is Test, InvariantTest {
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

    function _setUp() internal {
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

        termIssuer = new TermIssuer(
            address(this),
            91.25 days,
            0,
            ITerm(address(term)),
            IToken(address(rusd))
        );

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

        psm.grantRole(psm.MANAGER(), address(this));
        psm.grantRole(psm.CONTROLLER(), address(creditEnforcer));

        sm.grantRole(sm.CONTROLLER(), address(creditEnforcer));
        sm.grantRole(sm.MANAGER(), address(this));

        rusd.grantRole(rusd.MINTER(), address(psm));
        rusd.grantRole(rusd.MINTER(), address(sm));
        rusd.grantRole(rusd.MINTER(), address(this));

        srusd.grantRole(srusd.MINTER(), address(this));
        srusd.grantRole(srusd.MINTER(), address(sm));

        term.grantRole(term.MINTER(), address(termIssuer));

        termIssuer.grantRole(termIssuer.MANAGER(), address(this));
        termIssuer.grantRole(termIssuer.CONTROLLER(), address(creditEnforcer));

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));
        creditEnforcer.grantRole(creditEnforcer.SUPERVISOR(), address(this));
    }
}
