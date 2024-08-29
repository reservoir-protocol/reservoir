// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {Savingcoin} from "src/Savingcoin.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {ITermIssuer, TermIssuer} from "src/TermIssuer.sol";

import {ISavingModule, SavingModule} from "src/SavingModule.sol";
import {IPegStabilityModule, PegStabilityModule} from "src/PegStabilityModule.sol";

import {CreditEnforcer} from "src/CreditEnforcer.sol";

import {IToken} from "src/interfaces/IToken.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract MockPegStabilityModule {
    event Allocate(address indexed, uint256 indexed);
    event Withdraw(address indexed, uint256 indexed);

    event Mint(address indexed, address indexed, uint256 indexed);

    uint256 public totalValue;
    uint256 public totalRiskValue;

    uint256 public underlyingBalance;

    function mint(address from, address to, uint256 amount) external {
        emit Mint(from, to, amount);
    }

    function allocate(uint256 amount) external {
        emit Allocate(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        emit Withdraw(msg.sender, amount);
    }

    function setTotalValue(uint256 value) external {
        totalValue = value;
    }

    function setTotalRiskValue(uint256 value) external {
        totalRiskValue = value;
    }

    function setUnderlyingBalance(uint256 value) external {
        underlyingBalance = value;
    }
}

contract MockTermIssuer {
    event Mint(
        address indexed from,
        address indexed to,
        uint256 indexed id,
        uint256 amount
    );

    uint256 public totalDebt;

    uint256 public latestID;
    uint256 public earliestID;

    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maturityTimestamp;

    function mint(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external returns (uint256) {
        emit Mint(from, to, id, amount);

        return type(uint256).max;
    }

    function setTotalDebt(uint256 debt) external {
        totalDebt = debt;
    }

    function setLatestID(uint256 id) external {
        latestID = id;
    }

    function setEarliestID(uint256 id) external {
        earliestID = id;
    }

    function setTotalSupply(uint256 id, uint256 amount) external {
        totalSupply[id] = amount;
    }

    function setMaturityTimestamp(uint256 id, uint256 value) external {
        maturityTimestamp[id] = value;
    }
}

contract MockAssetAdapter {
    event Allocate(address indexed, uint256 indexed);
    event Withdraw(address indexed, uint256 indexed);

    event Redeem(address indexed, uint256 indexed);
    event Deposit(address indexed, uint256 indexed);

    uint256 public totalValue;
    uint256 public totalRiskValue;
    uint256 public duration = 10 days;

    function allocate(uint256 amount) external {
        emit Allocate(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        emit Withdraw(msg.sender, amount);
    }

    function deposit(uint256 amount) external {
        emit Deposit(msg.sender, amount);
    }

    function redeem(uint256 amount) external {
        emit Redeem(msg.sender, amount);
    }

    function setTotalValue(uint256 value) external {
        totalValue = value;
    }

    function setTotalRiskValue(uint256 value) external {
        totalRiskValue = value;
    }

    function setDuration(uint256 value) external {
        duration = value;
    }
}

contract MockStablecoin {
    uint256 public totalSupply;

    function setTotalSupply(uint256 supply) external {
        totalSupply = supply;
    }
}

contract CreditEnforcerUnitTest is Test {
    event Allocate(address indexed, uint256 indexed);
    event Withdraw(address indexed, uint256 indexed);

    event Mint(address indexed, address indexed, uint256 indexed);
    event Mint(address indexed, address indexed, uint256 indexed, uint256);

    event Redeem(address indexed, uint256 indexed);
    event Deposit(address indexed, uint256 indexed);

    ERC20DecimalsMock usdc;

    MockStablecoin rusd;
    Savingcoin srusd;

    MockTermIssuer termIssuer;

    SavingModule sm;
    MockPegStabilityModule psm;

    CreditEnforcer creditEnforcer;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function setUp() external {
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        rusd = new MockStablecoin();
        srusd = new Savingcoin(address(this), "Reservoir Savingcoin", "srUSD");

        termIssuer = new MockTermIssuer();

        psm = new MockPegStabilityModule();

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

        creditEnforcer.grantRole(creditEnforcer.MANAGER(), address(this));
        creditEnforcer.grantRole(creditEnforcer.SUPERVISOR(), address(this));

        creditEnforcer.setDuration(30 days);
    }

    function testInitialState() external {
        assertTrue(
            creditEnforcer.hasRole(creditEnforcer.SUPERVISOR(), address(this))
        );

        assertEq(address(creditEnforcer.underlying()), address(usdc));
        // assertEq(address(creditEnforcer.rusd()), address(rusd));

        assertEq(address(creditEnforcer.psm()), address(psm));
        assertEq(address(creditEnforcer.termIssuer()), address(termIssuer));

        assertEq(creditEnforcer.duration(), 30 days);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.psmDebtMax(), 0e6);
    }

    function testPSMDebtMax() external {
        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        _checkPSMDebtMaxValid(0e6);

        _checkPSMDebtMaxInvalid(0.000001e6);

        psm.setUnderlyingBalance(200_000e6);

        _checkPSMDebtMaxInvalid(0e6);

        creditEnforcer.setPSMDebtMax(300_000e6);
        assertEq(creditEnforcer.psmDebtMax(), 300_000e6);

        _checkPSMDebtMaxValid(100_000e6);

        _checkPSMDebtMaxInvalid(100_000e6 + 1);

        psm.setUnderlyingBalance(300_000e6);

        _checkPSMDebtMaxValid(0e6);

        _checkPSMDebtMaxInvalid(0.000001e6);
    }

    function testTermDebtMax() external {
        uint256[2][3] memory data;

        assertEq(termIssuer.totalSupply(1), 0e18);
        assertEq(termIssuer.totalSupply(8), 0e18);
        assertEq(termIssuer.totalSupply(124), 0e18);

        assertEq(creditEnforcer.termDebtMax(1), 0e18);
        assertEq(creditEnforcer.termDebtMax(8), 0e18);
        assertEq(creditEnforcer.termDebtMax(124), 0e18);

        assertEq(creditEnforcer.getTermDebtMax(1), 0e18);
        assertEq(creditEnforcer.getTermDebtMax(8), 0e18);
        assertEq(creditEnforcer.getTermDebtMax(124), 0e18);

        data[0] = [uint256(1), 0e18];
        data[1] = [uint256(8), 0e18];
        data[2] = [uint256(124), 0e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(1), 0.000000000000000001e18];
        data[1] = [uint256(8), 0.000000000000000001e18];
        data[2] = [uint256(124), 0.000000000000000001e18];

        _checkTermDebtMaxInvalid(data);

        termIssuer.setTotalSupply(1, 20_000e18);
        termIssuer.setTotalSupply(8, 100_000e18);
        termIssuer.setTotalSupply(124, 3_000e18);

        assertEq(termIssuer.totalSupply(1), 20_000e18);
        assertEq(termIssuer.totalSupply(8), 100_000e18);
        assertEq(termIssuer.totalSupply(124), 3_000e18);

        data[0] = [uint256(1), 0e18];
        data[1] = [uint256(8), 0e18];
        data[2] = [uint256(124), 0e18];

        _checkTermDebtMaxInvalid(data);

        data[0] = [uint256(1), 0.000000000000000001e18];
        data[1] = [uint256(8), 0.000000000000000001e18];
        data[2] = [uint256(124), 0.000000000000000001e18];

        _checkTermDebtMaxInvalid(data);

        creditEnforcer.setTermDebtMax(1, 200_000e18);
        creditEnforcer.setTermDebtMax(8, 200_000e18);
        creditEnforcer.setTermDebtMax(124, 200_000e18);

        assertEq(creditEnforcer.termDebtMax(1), 200_000e18);
        assertEq(creditEnforcer.termDebtMax(8), 200_000e18);
        assertEq(creditEnforcer.termDebtMax(124), 200_000e18);

        assertEq(creditEnforcer.getTermDebtMax(1), 200_000e18);
        assertEq(creditEnforcer.getTermDebtMax(8), 200_000e18);
        assertEq(creditEnforcer.getTermDebtMax(124), 200_000e18);

        data[0] = [uint256(1), 180_000e18];
        data[1] = [uint256(8), 100_000e18];
        data[2] = [uint256(124), 197_000e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(1), 180_000e18 + 1];
        data[1] = [uint256(8), 100_000e18 + 1];
        data[2] = [uint256(124), 197_000e18 + 1];

        _checkTermDebtMaxInvalid(data);
    }

    function testAssets() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        assertEq(creditEnforcer.assets(), 0);

        psm.setTotalValue(100_000e18);

        assertEq(creditEnforcer.assets(), 100_000e18);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assets(), 100_000e18);

        mockAssetAdapter1.setTotalValue(1_000e18);
        mockAssetAdapter2.setTotalValue(10_000e18);
        mockAssetAdapter3.setTotalValue(1_000_000e18);

        assertEq(creditEnforcer.assets(), 1_111_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assets(), 1_101_000e18);

        psm.setTotalValue(10_000e18);

        mockAssetAdapter1.setTotalValue(10_000e18);
        mockAssetAdapter3.setTotalValue(10_000e18);

        assertEq(creditEnforcer.assets(), 30_000e18);
    }

    function testShortTermAssets() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.shortTermAssets(), 0);

        psm.setTotalValue(1_020_000e18);

        assertEq(creditEnforcer.assets(), 1_020_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 1_020_000e18);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assets(), 1_020_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 1_020_000e18);

        mockAssetAdapter1.setTotalValue(2_400_000e18);
        mockAssetAdapter2.setTotalValue(4_000_000e18);
        mockAssetAdapter3.setTotalValue(1_000_000e18);

        assertEq(creditEnforcer.assets(), 8_420_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 8_420_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assets(), 7_420_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 7_420_000e18);

        psm.setTotalValue(20_000e18);

        mockAssetAdapter1.setTotalValue(1_400_000e18);
        mockAssetAdapter2.setTotalValue(2_000_000e18);

        assertEq(creditEnforcer.assets(), 3_420_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 3_420_000e18);
    }

    function testLiabilities() external {
        assertEq(creditEnforcer.liabilities(), 0);

        rusd.setTotalSupply(10_000e18);
        termIssuer.setTotalDebt(10_000e18);

        assertEq(creditEnforcer.liabilities(), 20_000e18);

        rusd.setTotalSupply(5_000e18);
        assertEq(creditEnforcer.liabilities(), 15_000e18);

        termIssuer.setTotalDebt(5_000e18);
        assertEq(creditEnforcer.liabilities(), 10_000e18);
    }

    function testExtendedLiabilities() external {
        assertEq(block.timestamp, 1);

        termIssuer.setLatestID(0);
        termIssuer.setEarliestID(0);

        termIssuer.setTotalSupply(0, 100_000e18);
        termIssuer.setMaturityTimestamp(0, block.timestamp);

        assertEq(creditEnforcer.extendedLiabilities(0), 0);

        termIssuer.setMaturityTimestamp(0, block.timestamp + 1);

        assertEq(creditEnforcer.extendedLiabilities(0), 100_000e18);
        assertEq(creditEnforcer.extendedLiabilities(1), 0);

        termIssuer.setTotalSupply(1, 100_000e18);
        termIssuer.setTotalSupply(2, 100_000e18);
        termIssuer.setTotalSupply(3, 100_000e18);
        termIssuer.setTotalSupply(4, 100_000e18);

        termIssuer.setMaturityTimestamp(1, block.timestamp + 90 days);
        termIssuer.setMaturityTimestamp(2, block.timestamp + 180 days);
        termIssuer.setMaturityTimestamp(3, block.timestamp + 270 days);
        termIssuer.setMaturityTimestamp(4, block.timestamp + 360 days);

        termIssuer.setLatestID(1);

        assertEq(creditEnforcer.extendedLiabilities(0), 200_000e18);
        assertEq(creditEnforcer.extendedLiabilities(1), 100_000e18);

        assertEq(creditEnforcer.extendedLiabilities(89 days), 100_000e18);
        assertEq(creditEnforcer.extendedLiabilities(90 days), 0);

        termIssuer.setLatestID(4);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 400_000e18);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 300_000e18);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 200_000e18);
        assertEq(creditEnforcer.extendedLiabilities(320 days), 100_000e18);

        vm.warp(block.timestamp + 90 days);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 300_000e18);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 300_000e18);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 200_000e18);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 100_000e18);

        termIssuer.setEarliestID(2);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 300_000e18);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 300_000e18);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 200_000e18);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 100_000e18);

        termIssuer.setEarliestID(4);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 100_000e18);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 100_000e18);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 100_000e18);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 100_000e18);

        termIssuer.setEarliestID(5);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 0);

        termIssuer.setEarliestID(6);

        assertEq(creditEnforcer.extendedLiabilities(0 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(80 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(160 days), 0);
        assertEq(creditEnforcer.extendedLiabilities(240 days), 0);
    }

    function testShortTermLiabilities() external {
        assertEq(block.timestamp, 1);

        assertEq(creditEnforcer.liabilities(), 0);
        assertEq(creditEnforcer.duration(), 30 days);

        termIssuer.setLatestID(0);
        termIssuer.setEarliestID(0);

        termIssuer.setTotalSupply(0, 100_000e18);
        termIssuer.setTotalSupply(1, 100_000e18);
        termIssuer.setTotalSupply(2, 100_000e18);
        termIssuer.setTotalSupply(3, 100_000e18);
        termIssuer.setTotalSupply(4, 100_000e18);

        termIssuer.setMaturityTimestamp(0, block.timestamp);
        termIssuer.setMaturityTimestamp(1, block.timestamp + 90 days);
        termIssuer.setMaturityTimestamp(2, block.timestamp + 180 days);
        termIssuer.setMaturityTimestamp(3, block.timestamp + 270 days);
        termIssuer.setMaturityTimestamp(4, block.timestamp + 360 days);

        termIssuer.setTotalDebt(500_000e18);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(0 days), 0);

        assertEq(creditEnforcer.shortTermLiabilities(), 500_000e18);

        termIssuer.setLatestID(1);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 100_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 400_000e18);

        termIssuer.setLatestID(4);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 400_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        vm.warp(block.timestamp + 90 days);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 300_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 200_000e18);

        vm.warp(block.timestamp + 90 days);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 200_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 300_000e18);

        vm.warp(block.timestamp + 90 days);

        assertEq(creditEnforcer.liabilities(), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 100_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 400_000e18);
    }

    function testEquity() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.equity(), 0);

        psm.setTotalValue(10_000e18);

        assertEq(creditEnforcer.assets(), 10_000e18);
        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.equity(), 10_000e18);

        rusd.setTotalSupply(20_000e18);
        termIssuer.setTotalDebt(20_000e18);

        assertEq(creditEnforcer.assets(), 10_000e18);
        assertEq(creditEnforcer.liabilities(), 40_000e18);

        assertEq(creditEnforcer.equity(), 0);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assets(), 10_000e18);
        assertEq(creditEnforcer.liabilities(), 40_000e18);

        assertEq(creditEnforcer.equity(), 0);

        mockAssetAdapter1.setTotalValue(10_000e18);
        mockAssetAdapter2.setTotalValue(20_000e18);
        mockAssetAdapter3.setTotalValue(40_000e18);

        assertEq(creditEnforcer.assets(), 80_000e18);
        assertEq(creditEnforcer.liabilities(), 40_000e18);

        assertEq(creditEnforcer.equity(), 40_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assets(), 60_000e18);
        assertEq(creditEnforcer.liabilities(), 40_000e18);

        assertEq(creditEnforcer.equity(), 20_000e18);

        rusd.setTotalSupply(5_000e18);

        assertEq(creditEnforcer.assets(), 60_000e18);
        assertEq(creditEnforcer.liabilities(), 25_000e18);

        assertEq(creditEnforcer.equity(), 35_000e18);

        termIssuer.setTotalDebt(5_000e18);

        assertEq(creditEnforcer.assets(), 60_000e18);
        assertEq(creditEnforcer.liabilities(), 10_000e18);

        assertEq(creditEnforcer.equity(), 50_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assets(), 20_000e18);
        assertEq(creditEnforcer.liabilities(), 10_000e18);

        assertEq(creditEnforcer.equity(), 10_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter1));

        assertEq(creditEnforcer.assets(), 10_000e18);
        assertEq(creditEnforcer.liabilities(), 10_000e18);

        assertEq(creditEnforcer.equity(), 0);
    }

    function testRiskWeightedAssets() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        psm.setTotalRiskValue(100_000e18);

        assertEq(creditEnforcer.riskWeightedAssets(), 100_000e18);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.riskWeightedAssets(), 100_000e18);

        mockAssetAdapter1.setTotalRiskValue(25_000e18);
        mockAssetAdapter2.setTotalRiskValue(240_000e18);
        mockAssetAdapter3.setTotalRiskValue(500_000e18);

        assertEq(creditEnforcer.riskWeightedAssets(), 865_000e18);

        // TODO: Check the list of all the funds

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter1));

        assertEq(creditEnforcer.riskWeightedAssets(), 840_000e18);

        psm.setTotalRiskValue(200_000e18);

        mockAssetAdapter2.setTotalRiskValue(200_000e18);
        mockAssetAdapter3.setTotalRiskValue(600_000e18);

        assertEq(creditEnforcer.riskWeightedAssets(), 1_000_000e18);
    }

    function testAssetRatio() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.assetRatio(), 0e6);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));

        psm.setTotalValue(1_000_000e18);
        mockAssetAdapter1.setTotalValue(1_000_000e18);

        assertEq(creditEnforcer.assets(), 2_000_000e18);
        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.assetRatio(), type(uint256).max);

        rusd.setTotalSupply(1_000_000e18);
        termIssuer.setTotalDebt(1_000_000e18);

        assertEq(creditEnforcer.assets(), 2_000_000e18);
        assertEq(creditEnforcer.liabilities(), 2_000_000e18);

        assertEq(creditEnforcer.assetRatio(), 1e6);

        rusd.setTotalSupply(500_000e18);
        termIssuer.setTotalDebt(500_000e18);

        assertEq(creditEnforcer.assetRatio(), 2e6);

        psm.setTotalValue(250_000e18);
        mockAssetAdapter1.setTotalValue(250_000e18);

        assertEq(creditEnforcer.assetRatio(), 0.5e6);

        // TODO: Check ratios
    }

    function testEquityRatio() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.equity(), 0);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        assertEq(creditEnforcer.equityRatio(), 0e6);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));

        psm.setTotalValue(200_000e18);

        mockAssetAdapter1.setTotalValue(200_000e18);

        rusd.setTotalSupply(100_000e18);
        termIssuer.setTotalDebt(100_000e18);

        assertEq(creditEnforcer.assets(), 400_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);

        assertEq(creditEnforcer.equity(), 200_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        assertEq(creditEnforcer.equityRatio(), type(uint256).max);

        psm.setTotalRiskValue(100_000e18);

        mockAssetAdapter1.setTotalRiskValue(100_000e18);

        assertEq(creditEnforcer.assets(), 400_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);

        assertEq(creditEnforcer.equity(), 200_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 200_000e18);

        assertEq(creditEnforcer.equityRatio(), 1e6);

        psm.setTotalValue(400_000e18);

        mockAssetAdapter1.setTotalValue(400_000e18);

        assertEq(creditEnforcer.assets(), 800_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);

        assertEq(creditEnforcer.equity(), 600_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 200_000e18);

        assertEq(creditEnforcer.equityRatio(), 3e6);

        psm.setTotalRiskValue(400_000e18);

        mockAssetAdapter1.setTotalRiskValue(400_000e18);

        assertEq(creditEnforcer.assets(), 800_000e18);
        assertEq(creditEnforcer.liabilities(), 200_000e18);

        assertEq(creditEnforcer.equity(), 600_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 800_000e18);

        assertEq(creditEnforcer.equityRatio(), 0.75e6);

        // TODO: Check ratios
    }

    function testLiquidityRatio() external {
        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.extendedLiabilities(0), 0);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 0);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 0);
        assertEq(creditEnforcer.shortTermAssets(), 0);

        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        psm.setTotalValue(100_100e18);

        mockAssetAdapter1.setTotalValue(10_000e18);
        mockAssetAdapter2.setTotalValue(20_000e18);
        mockAssetAdapter3.setTotalValue(40_000e18);

        termIssuer.setLatestID(15);
        termIssuer.setEarliestID(11);

        termIssuer.setTotalSupply(11, 204_000e18);
        termIssuer.setTotalSupply(12, 140_800e18);
        termIssuer.setTotalSupply(13, 116_000e18);
        termIssuer.setTotalSupply(14, 300_100e18);
        termIssuer.setTotalSupply(15, 400_000e18);

        termIssuer.setMaturityTimestamp(11, 11 * 90 days);
        termIssuer.setMaturityTimestamp(12, 12 * 90 days);
        termIssuer.setMaturityTimestamp(13, 13 * 90 days);
        termIssuer.setMaturityTimestamp(14, 14 * 90 days);
        termIssuer.setMaturityTimestamp(15, 15 * 90 days);

        termIssuer.setTotalDebt(1_160_900e18);

        assertEq(creditEnforcer.liabilities(), 1_160_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 1_160_900e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 1_160_900e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 170_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 170_100e18);

        assertEq(creditEnforcer.liquidityRatio(), type(uint256).max);

        rusd.setTotalSupply(680_000e18);

        assertEq(creditEnforcer.liabilities(), 1_840_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 1_160_900e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 1_160_900e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 680_000e18);

        assertEq(creditEnforcer.assets(), 170_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 170_100e18);

        assertEq(creditEnforcer.liquidityRatio(), 0.250147e6);

        vm.warp(block.timestamp + 11 * 90 days);

        assertEq(creditEnforcer.liabilities(), 1_840_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 956_900e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 956_900e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 884_000e18);

        assertEq(creditEnforcer.assets(), 170_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 170_100e18);

        assertEq(creditEnforcer.liquidityRatio(), 0.19242e6);

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter1));

        mockAssetAdapter2.setTotalValue(10_000e18);
        mockAssetAdapter3.setTotalValue(10_000e18);

        assertEq(creditEnforcer.liabilities(), 1_840_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 956_900e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 956_900e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 884_000e18);

        assertEq(creditEnforcer.assets(), 120_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 120_100e18);

        assertEq(creditEnforcer.liquidityRatio(), 0.135859e6);

        vm.warp(block.timestamp + 90 days);

        assertEq(creditEnforcer.liabilities(), 1_840_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 816_100e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 816_100e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 1_024_800e18);

        assertEq(creditEnforcer.assets(), 120_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 120_100e18);

        assertEq(creditEnforcer.liquidityRatio(), 0.117193e6);

        vm.warp(block.timestamp + 60 days);

        assertEq(creditEnforcer.liabilities(), 1_840_900e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 816_100e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 700_100e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 1_140_800e18);

        assertEq(creditEnforcer.assets(), 120_100e18);
        assertEq(creditEnforcer.shortTermAssets(), 120_100e18);

        assertEq(creditEnforcer.liquidityRatio(), 0.105276e6);
    }

    function testInvalidStablecoinMint() external {
        bool valid;
        string memory message;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        _checkPSMDebtMaxValid(0e6);

        _checkPSMDebtMaxInvalid(0.000001e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(1e6);

        vm.expectRevert("CE: amount exceeds PSM debt max");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        creditEnforcer.setPSMDebtMax(100_000e6);

        _checkPSMDebtMaxValid(0e6);

        _checkPSMDebtMaxValid(1e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 1e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(1e6);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 1e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        psm.setTotalValue(100_000e18);

        psm.setTotalRiskValue(100e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(200_000e18);

        mockAssetAdapter1.setTotalRiskValue(10_000e18);
        mockAssetAdapter2.setTotalRiskValue(10_000e18);
        mockAssetAdapter3.setTotalRiskValue(10_000e18);

        termIssuer.setLatestID(68);
        termIssuer.setEarliestID(64);

        termIssuer.setTotalSupply(64, 104_000e18);
        termIssuer.setTotalSupply(65, 140_800e18);
        termIssuer.setTotalSupply(66, 116_000e18);
        termIssuer.setTotalSupply(67, 100_100e18);
        termIssuer.setTotalSupply(68, 100_040e18);

        termIssuer.setMaturityTimestamp(64, 64 * 90 days);
        termIssuer.setMaturityTimestamp(65, 65 * 90 days);
        termIssuer.setMaturityTimestamp(66, 66 * 90 days);
        termIssuer.setMaturityTimestamp(67, 67 * 90 days);
        termIssuer.setMaturityTimestamp(68, 68 * 90 days);

        rusd.setTotalSupply(100_000e18);
        termIssuer.setTotalDebt(560_940e18);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.liabilities(), 660_940e18);

        assertEq(creditEnforcer.assetRatio(), 1.059097e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        creditEnforcer.setAssetRatioMin(1.05e6);
        // creditEnforcer.setAssetRatioMin(150_000);

        assertEq(creditEnforcer.equity(), 39_060e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 30_100e18);

        assertEq(creditEnforcer.equityRatio(), 1.297674e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid equity ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 1e18);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(1e6);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 1e18);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        creditEnforcer.setEquityRatioMin(1.05e6);
        // creditEnforcer.setEquityRatioMin(150_000);

        assertEq(creditEnforcer.duration(), 30 days);
        assertEq(creditEnforcer.liabilities(), 660_940e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 560_940e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 560_940e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 700_000e18);

        assertEq(creditEnforcer.liquidityRatio(), 7e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid liquidity ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 1e18);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(1e6);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 1e18);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 1e6);

        creditEnforcer.setLiquidityRatioMin(1.05e6);
        // creditEnforcer.setLiquidityRatioMin(150_000);

        vm.warp(block.timestamp + 68 * 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.059097e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.247994e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.519097e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 2.030162e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");
    }

    function testSuccessfulStablecoinMint() external {
        bool valid;
        string memory message;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        psm.setTotalValue(100_000e18);

        psm.setTotalRiskValue(100e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(200_000e18);

        mockAssetAdapter1.setTotalRiskValue(10_000e18);
        mockAssetAdapter2.setTotalRiskValue(15_000e18);
        mockAssetAdapter3.setTotalRiskValue(20_000e18);

        termIssuer.setLatestID(22);
        termIssuer.setEarliestID(18);

        termIssuer.setTotalSupply(18, 100_000e18);
        termIssuer.setTotalSupply(19, 100_000e18);
        termIssuer.setTotalSupply(20, 100_000e18);
        termIssuer.setTotalSupply(21, 100_000e18);
        termIssuer.setTotalSupply(22, 100_000e18);

        termIssuer.setMaturityTimestamp(18, 18 * 92.5 days);
        termIssuer.setMaturityTimestamp(19, 19 * 92.5 days);
        termIssuer.setMaturityTimestamp(20, 20 * 92.5 days);
        termIssuer.setMaturityTimestamp(21, 21 * 92.5 days);
        termIssuer.setMaturityTimestamp(22, 22 * 92.5 days);

        rusd.setTotalSupply(100_000e18);
        termIssuer.setTotalDebt(500_000e18);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        creditEnforcer.setPSMDebtMax(1_000_000e6);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 700_000e18);

        assertEq(creditEnforcer.duration(), 30 days);
        assertEq(creditEnforcer.liabilities(), 600_000e18);

        assertEq(creditEnforcer.equity(), 100_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 45_100e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 500_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        assertEq(creditEnforcer.assetRatio(), 1_166_666);
        assertEq(creditEnforcer.equityRatio(), 2_217_294);
        assertEq(creditEnforcer.liquidityRatio(), 7_000_000);

        vm.warp(block.timestamp + 22 * 92.5 days - 20 days);

        _checkPSMDebtMaxValid(1e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.expectEmit(true, true, true, true);
        emit Mint(eoa1, eoa1, 10e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(10e6);

        vm.expectEmit(true, true, true, true);
        emit Mint(eoa1, eoa2, 10e6);

        vm.prank(eoa1);
        creditEnforcer.mintStablecoin(eoa2, 10e6);
    }

    function testInvalidTermMint() external {
        uint256 cost;

        bool valid;
        string memory message;

        uint256[2][3] memory data;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        data[0] = [uint256(27), 0e18];
        data[1] = [uint256(28), 0e18];
        data[2] = [uint256(29), 0e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(27), 0.000000000000000001e18];
        data[1] = [uint256(28), 0.000000000000000001e18];
        data[2] = [uint256(29), 0.000000000000000001e18];

        _checkTermDebtMaxInvalid(data);

        data[0] = [uint256(30), 0e18];
        data[1] = [uint256(31), 0e18];
        data[2] = [uint256(32), 0e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(30), 0.000000000000000001e18];
        data[1] = [uint256(31), 0.000000000000000001e18];
        data[2] = [uint256(32), 0.000000000000000001e18];

        _checkTermDebtMaxInvalid(data);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(28, 100e18);

        console.log(" * cost %d", cost);

        vm.expectRevert("CE: amount exceeds term minter debt max");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(eoa2, 28, 100e18);

        console.log(" * cost %d", cost);

        creditEnforcer.setTermDebtMax(27, 2_000_000e18);
        creditEnforcer.setTermDebtMax(28, 2_000_000e18);
        creditEnforcer.setTermDebtMax(29, 2_000_000e18);

        creditEnforcer.setTermDebtMax(30, 2_000_000e18);
        creditEnforcer.setTermDebtMax(31, 2_000_000e18);
        creditEnforcer.setTermDebtMax(32, 2_000_000e18);

        data[0] = [uint256(27), 0e18];
        data[1] = [uint256(28), 0e18];
        data[2] = [uint256(29), 0e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(27), 1e18];
        data[1] = [uint256(28), 1e18];
        data[2] = [uint256(29), 1e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(30), 0e18];
        data[1] = [uint256(31), 0e18];
        data[2] = [uint256(32), 0e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(30), 1e18];
        data[1] = [uint256(31), 1e18];
        data[2] = [uint256(32), 1e18];

        _checkTermDebtMaxValid(data);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 28, 100e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(28, 100e18);

        console.log(" * cost %d", cost);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 28, 100e18);

        vm.expectRevert("CE: invalid asset ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(eoa2, 28, 100e18);

        console.log(" * cost %d", cost);

        psm.setTotalValue(100_000e18);

        psm.setTotalRiskValue(100e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(200_000e18);

        mockAssetAdapter1.setTotalRiskValue(10_000e18);
        mockAssetAdapter2.setTotalRiskValue(10_000e18);
        mockAssetAdapter3.setTotalRiskValue(10_000e18);

        termIssuer.setLatestID(30);
        termIssuer.setEarliestID(26);

        termIssuer.setTotalSupply(26, 100_000e18);
        termIssuer.setTotalSupply(27, 100_000e18);
        termIssuer.setTotalSupply(28, 100_000e18);
        termIssuer.setTotalSupply(29, 100_000e18);
        termIssuer.setTotalSupply(30, 100_000e18);

        termIssuer.setMaturityTimestamp(26, 26 * 90 days);
        termIssuer.setMaturityTimestamp(27, 27 * 90 days);
        termIssuer.setMaturityTimestamp(28, 28 * 90 days);
        termIssuer.setMaturityTimestamp(29, 29 * 90 days);
        termIssuer.setMaturityTimestamp(30, 30 * 90 days);

        rusd.setTotalSupply(100_000e18);
        termIssuer.setTotalDebt(500_000e18);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.liabilities(), 600_000e18);

        assertEq(creditEnforcer.assetRatio(), 1.166666e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid asset ratio");

        creditEnforcer.setAssetRatioMin(1.05e6);
        // creditEnforcer.setAssetRatioMin(150_000);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid equity ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 28, 100e18);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(28, 100e18);

        console.log(" * cost %d", cost);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 28, 100e18);

        vm.expectRevert("CE: invalid equity ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(eoa2, 28, 100e18);

        console.log(" * cost %d", cost);

        creditEnforcer.setEquityRatioMin(1.05e6);
        // creditEnforcer.setEquityRatioMin(150_000);

        assertEq(creditEnforcer.duration(), 30 days);
        assertEq(creditEnforcer.liabilities(), 600_000e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 500_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 700_000e18);

        assertEq(creditEnforcer.liquidityRatio(), 7e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertFalse(valid);
        assertEq(message, "CE: invalid liquidity ratio");

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa1, 28, 100e18);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(28, 100e18);

        console.log(" * cost %d", cost);

        // vm.expectEmit(true, true, true, true);
        // emit Mint(eoa1, eoa2, 28, 100e18);

        vm.expectRevert("CE: invalid liquidity ratio");

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(eoa2, 28, 100e18);

        console.log(" * cost %d", cost);

        creditEnforcer.setLiquidityRatioMin(1.05e6);
        // creditEnforcer.setLiquidityRatioMin(150_000);

        vm.warp(block.timestamp + 30 * 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.166666e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.4e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 1.75e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.warp(block.timestamp - 90 days);

        assertEq(creditEnforcer.liquidityRatio(), 2.333333e6);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");
    }

    function testSuccessfulTermMint() external {
        uint256 cost;

        bool valid;
        string memory message;

        uint256[2][3] memory data;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.psmDebtMax(), 0e6);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        psm.setTotalValue(100_000e18);

        psm.setTotalRiskValue(100e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(200_000e18);

        mockAssetAdapter1.setTotalRiskValue(10_000e18);
        mockAssetAdapter2.setTotalRiskValue(15_000e18);
        mockAssetAdapter3.setTotalRiskValue(20_000e18);

        termIssuer.setLatestID(22);
        termIssuer.setEarliestID(18);

        termIssuer.setTotalSupply(18, 100_000e18);
        termIssuer.setTotalSupply(19, 100_000e18);
        termIssuer.setTotalSupply(20, 100_000e18);
        termIssuer.setTotalSupply(21, 100_000e18);
        termIssuer.setTotalSupply(22, 100_000e18);

        termIssuer.setMaturityTimestamp(18, 18 * 92.5 days);
        termIssuer.setMaturityTimestamp(19, 19 * 92.5 days);
        termIssuer.setMaturityTimestamp(20, 20 * 92.5 days);
        termIssuer.setMaturityTimestamp(21, 21 * 92.5 days);
        termIssuer.setMaturityTimestamp(22, 22 * 92.5 days);

        rusd.setTotalSupply(100_000e18);
        termIssuer.setTotalDebt(500_000e18);

        creditEnforcer.setAssetRatioMin(1.05e6);
        creditEnforcer.setEquityRatioMin(1.05e6);
        creditEnforcer.setLiquidityRatioMin(1.05e6);

        creditEnforcer.setTermDebtMax(18, 2_000_000e18);
        creditEnforcer.setTermDebtMax(19, 2_000_000e18);
        creditEnforcer.setTermDebtMax(20, 2_000_000e18);

        creditEnforcer.setTermDebtMax(21, 2_000_000e18);
        creditEnforcer.setTermDebtMax(22, 2_000_000e18);
        creditEnforcer.setTermDebtMax(23, 2_000_000e18);

        assertEq(creditEnforcer.assets(), 700_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 700_000e18);

        assertEq(creditEnforcer.duration(), 30 days);
        assertEq(creditEnforcer.liabilities(), 600_000e18);

        assertEq(creditEnforcer.equity(), 100_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 45_100e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 500_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 500_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 100_000e18);

        assertEq(creditEnforcer.assetRatio(), 1_166_666);
        assertEq(creditEnforcer.equityRatio(), 2_217_294);
        assertEq(creditEnforcer.liquidityRatio(), 7_000_000);

        vm.warp(block.timestamp + 22 * 92.5 days - 20 days);

        data[0] = [uint256(18), 0.000000000000000001e18];
        data[1] = [uint256(19), 0.000000000000000001e18];
        data[2] = [uint256(20), 0.000000000000000001e18];

        _checkTermDebtMaxValid(data);

        data[0] = [uint256(21), 0.000000000000000001e18];
        data[1] = [uint256(22), 0.000000000000000001e18];
        data[2] = [uint256(23), 0.000000000000000001e18];

        _checkTermDebtMaxValid(data);

        (valid, message) = creditEnforcer.checkRatios();

        assertTrue(valid);
        assertEq(message, "");

        vm.expectEmit(true, true, true, true);
        emit Mint(eoa1, eoa1, 20, 100e18);

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(20, 100e18);

        assertEq(cost, type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit Mint(eoa1, eoa2, 20, 100e18);

        vm.prank(eoa1);
        cost = creditEnforcer.mintTerm(eoa2, 20, 100e18);

        assertEq(cost, type(uint256).max);
    }

    function testAllocate() external {
        uint256 allowance;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assetAdapterLength(), 3);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Withdraw(address(creditEnforcer), 1e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        emit Allocate(address(creditEnforcer), 1e6);

        creditEnforcer.allocate(0, 1e6);

        allowance = usdc.allowance(
            address(creditEnforcer),
            address(mockAssetAdapter1)
        );

        assertEq(allowance, 1e6);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Withdraw(address(creditEnforcer), 240e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Allocate(address(creditEnforcer), 240e6);

        creditEnforcer.allocate(2, 240e6);

        allowance = usdc.allowance(
            address(creditEnforcer),
            address(mockAssetAdapter3)
        );

        assertEq(allowance, 240e6);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.allocate(4, 240e6);

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assetAdapterLength(), 2);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.allocate(2, 10e6);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Withdraw(address(creditEnforcer), 10e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Allocate(address(creditEnforcer), 10e6);

        creditEnforcer.allocate(1, 10e6);

        allowance = usdc.allowance(
            address(creditEnforcer),
            address(mockAssetAdapter3)
        );

        assertEq(allowance, 10e6);
    }

    function testWithdraw() external {
        uint256 allowance;

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.assetAdapterLength(), 3);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        emit Withdraw(address(creditEnforcer), 1e6);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Allocate(address(creditEnforcer), 1e6);

        creditEnforcer.withdraw(0, 1e6);

        allowance = usdc.allowance(address(creditEnforcer), address(psm));

        assertEq(allowance, 1e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Withdraw(address(creditEnforcer), 240e6);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Allocate(address(creditEnforcer), 240e6);

        creditEnforcer.withdraw(2, 240e6);

        allowance = usdc.allowance(address(creditEnforcer), address(psm));

        assertEq(allowance, 240e6);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.withdraw(4, 240e6);

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assetAdapterLength(), 2);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.withdraw(2, 10e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Withdraw(address(creditEnforcer), 10e6);

        vm.expectEmit(true, true, true, true, address(psm));
        emit Allocate(address(creditEnforcer), 10e6);

        creditEnforcer.withdraw(1, 10e6);

        allowance = usdc.allowance(address(creditEnforcer), address(psm));

        assertEq(allowance, 10e6);
    }

    function testDeposit() external {
        assertEq(block.timestamp, 1);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.extendedLiabilities(0), 0);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 0);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 0);

        assertEq(creditEnforcer.shortTermAssets(), 0);

        assertEq(creditEnforcer.equity(), 0);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        psm.setTotalValue(800_000e18);
        psm.setTotalRiskValue(800e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(400_000e18);

        mockAssetAdapter1.setTotalRiskValue(20_000e18);
        mockAssetAdapter2.setTotalRiskValue(20_000e18);
        mockAssetAdapter3.setTotalRiskValue(40_000e18);

        termIssuer.setLatestID(86);
        termIssuer.setEarliestID(82);

        termIssuer.setTotalSupply(82, 240_000e18);
        termIssuer.setTotalSupply(83, 120_000e18);
        termIssuer.setTotalSupply(84, 160_000e18);
        termIssuer.setTotalSupply(85, 300_000e18);
        termIssuer.setTotalSupply(86, 400_000e18);

        termIssuer.setMaturityTimestamp(82, 82 * 92.5 days);
        termIssuer.setMaturityTimestamp(83, 83 * 92.5 days);
        termIssuer.setMaturityTimestamp(84, 84 * 92.5 days);
        termIssuer.setMaturityTimestamp(85, 85 * 92.5 days);
        termIssuer.setMaturityTimestamp(86, 86 * 92.5 days);

        termIssuer.setTotalDebt(1_220_000e18);

        assertEq(creditEnforcer.liabilities(), 1_220_000e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 1_220_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 1_220_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 1_600_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 1_600_000e18);

        assertEq(creditEnforcer.equity(), 380_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 80_800e18);

        assertEq(creditEnforcer.assetRatio(), 1.311475e6);
        assertEq(creditEnforcer.equityRatio(), 4.702970e6);
        assertEq(creditEnforcer.liquidityRatio(), type(uint256).max);

        assertEq(creditEnforcer.assetAdapterLength(), 3);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid asset ratio");
        creditEnforcer.deposit(0, 1_000e6);

        creditEnforcer.setAssetRatioMin(1.05e6);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid equity ratio");
        creditEnforcer.deposit(0, 1_000e6);

        creditEnforcer.setEquityRatioMin(1.05e6);

        vm.warp(block.timestamp + 84 * 92.5 days);

        assertEq(creditEnforcer.liquidityRatio(), 3.076923e6);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid liquidity ratio");
        creditEnforcer.deposit(0, 1_000e6);

        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        emit Deposit(address(creditEnforcer), 1_000e6);

        creditEnforcer.deposit(0, 1_000e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Deposit(address(creditEnforcer), 1_000e6);

        creditEnforcer.deposit(2, 1_000e6);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.deposit(4, 1_000e6);

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assetAdapterLength(), 2);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.deposit(2, 1_000e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Deposit(address(creditEnforcer), 1_000e6);

        creditEnforcer.deposit(1, 1_000e6);
    }

    function testRedeem() external {
        assertEq(block.timestamp, 1);

        assertEq(creditEnforcer.assetRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.equityRatioMin(), type(uint256).max);
        assertEq(creditEnforcer.liquidityRatioMin(), type(uint256).max);

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        assertEq(creditEnforcer.liabilities(), 0);

        assertEq(creditEnforcer.extendedLiabilities(0), 0);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 0);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 0);

        assertEq(creditEnforcer.shortTermAssets(), 0);

        assertEq(creditEnforcer.equity(), 0);
        assertEq(creditEnforcer.riskWeightedAssets(), 0);

        assertEq(creditEnforcer.assetRatio(), 0e6);
        assertEq(creditEnforcer.equityRatio(), 0e6);
        assertEq(creditEnforcer.liquidityRatio(), 0e6);

        psm.setTotalValue(800_000e18);
        psm.setTotalRiskValue(800e18);

        mockAssetAdapter1.setTotalValue(200_000e18);
        mockAssetAdapter2.setTotalValue(200_000e18);
        mockAssetAdapter3.setTotalValue(400_000e18);

        mockAssetAdapter1.setTotalRiskValue(20_000e18);
        mockAssetAdapter2.setTotalRiskValue(20_000e18);
        mockAssetAdapter3.setTotalRiskValue(40_000e18);

        termIssuer.setLatestID(86);
        termIssuer.setEarliestID(82);

        termIssuer.setTotalSupply(82, 240_000e18);
        termIssuer.setTotalSupply(83, 120_000e18);
        termIssuer.setTotalSupply(84, 160_000e18);
        termIssuer.setTotalSupply(85, 300_000e18);
        termIssuer.setTotalSupply(86, 400_000e18);

        termIssuer.setMaturityTimestamp(82, 82 * 92.5 days);
        termIssuer.setMaturityTimestamp(83, 83 * 92.5 days);
        termIssuer.setMaturityTimestamp(84, 84 * 92.5 days);
        termIssuer.setMaturityTimestamp(85, 85 * 92.5 days);
        termIssuer.setMaturityTimestamp(86, 86 * 92.5 days);

        termIssuer.setTotalDebt(1_220_000e18);

        assertEq(creditEnforcer.liabilities(), 1_220_000e18);

        assertEq(creditEnforcer.extendedLiabilities(0), 1_220_000e18);
        assertEq(creditEnforcer.extendedLiabilities(30 days), 1_220_000e18);

        assertEq(creditEnforcer.shortTermLiabilities(), 0);

        assertEq(creditEnforcer.assets(), 1_600_000e18);
        assertEq(creditEnforcer.shortTermAssets(), 1_600_000e18);

        assertEq(creditEnforcer.equity(), 380_000e18);
        assertEq(creditEnforcer.riskWeightedAssets(), 80_800e18);

        assertEq(creditEnforcer.assetRatio(), 1.311475e6);
        assertEq(creditEnforcer.equityRatio(), 4.702970e6);
        assertEq(creditEnforcer.liquidityRatio(), type(uint256).max);

        assertEq(creditEnforcer.assetAdapterLength(), 3);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid asset ratio");
        creditEnforcer.redeem(0, 1_000e6);

        creditEnforcer.setAssetRatioMin(1.05e6);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid equity ratio");
        creditEnforcer.redeem(0, 1_000e6);

        creditEnforcer.setEquityRatioMin(1.05e6);

        vm.warp(block.timestamp + 84 * 92.5 days);

        assertEq(creditEnforcer.liquidityRatio(), 3.076923e6);

        // vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        // emit Deposit(eoa1, 1_000e6);

        vm.expectRevert("CE: invalid liquidity ratio");
        creditEnforcer.redeem(0, 1_000e6);

        creditEnforcer.setLiquidityRatioMin(1.05e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter1));
        emit Redeem(address(creditEnforcer), 1_000e6);

        creditEnforcer.redeem(0, 1_000e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Redeem(address(creditEnforcer), 1_000e6);

        creditEnforcer.redeem(2, 1_000e6);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.redeem(4, 1_000e6);

        creditEnforcer.removeAssetAdapter(address(mockAssetAdapter2));

        assertEq(creditEnforcer.assetAdapterLength(), 2);

        vm.expectRevert("CE: Asset Adapter index out of bounds");
        creditEnforcer.redeem(2, 1_000e6);

        vm.expectEmit(true, true, true, true, address(mockAssetAdapter3));
        emit Redeem(address(creditEnforcer), 1_000e6);

        creditEnforcer.redeem(1, 1_000e6);
    }

    function testassetAdapterLength(uint8 fundCount) external {
        vm.assume(fundCount < 10);

        assertEq(creditEnforcer.assetAdapterLength(), 0);

        for (uint256 i = 0; i < fundCount; i++) {
            creditEnforcer.addAssetAdapter(address(new MockAssetAdapter()));
        }

        assertEq(creditEnforcer.assetAdapterLength(), fundCount);
    }

    function testgetAssetAdapter(uint8 fundCount) external {
        vm.assume(fundCount < 10);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            CreditEnforcer.AssetAdapter memory assetAdapter = creditEnforcer
                .getAssetAdapter(address(fund));
            assertEq(assetAdapter.set, true);
            assertEq(assetAdapter.index, i);
        }
    }

    function testgetAssetAdapterList(
        uint8 fundCount,
        uint8 startIndex,
        uint8 length
    ) external {
        vm.assume(fundCount < 10);
        vm.assume(startIndex < fundCount);
        vm.assume(length <= fundCount - startIndex);

        address[] memory assetAdapters = new address[](fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            assetAdapters[i] = address(fund);
        }

        address[] memory fetchedAdapters = creditEnforcer.getAssetAdapterList(
            startIndex,
            length
        );

        for (uint256 i = 0; i < length; i++) {
            assertEq(fetchedAdapters[i], assetAdapters[startIndex + i]);
        }
    }

    function testaddAssetAdapter(uint8 fundCount) external {
        vm.assume(fundCount < 10);

        address[] memory assetAdapters = new address[](fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            assetAdapters[i] = address(fund);
        }

        assertEq(creditEnforcer.assetAdapterLength(), fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            assertEq(creditEnforcer.assetAdapterList(i), assetAdapters[i]);
            CreditEnforcer.AssetAdapter memory assetAdapter = creditEnforcer
                .getAssetAdapter(assetAdapters[i]);
            assertEq(assetAdapter.set, true);
            assertEq(assetAdapter.index, i);
        }
    }

    function testaddAssetAdapterExisting(
        uint8 fundCount,
        uint8 duplicateFundIndex
    ) external {
        vm.assume(fundCount < 10);
        vm.assume(duplicateFundIndex < fundCount);

        address[] memory assetAdapters = new address[](fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            assetAdapters[i] = address(fund);
        }

        vm.expectRevert("CE: adapter already set");
        creditEnforcer.addAssetAdapter(assetAdapters[duplicateFundIndex]);
    }

    function testaddAssetAdapterUnauthorized() external {
        MockAssetAdapter fund = new MockAssetAdapter();

        vm.expectRevert();
        vm.prank(eoa1);
        creditEnforcer.addAssetAdapter(address(fund));
    }

    function testremoveAssetAdapter(
        uint8 fundCount,
        uint8 removedFundIndex
    ) external {
        vm.assume(fundCount < 10);
        vm.assume(removedFundIndex < fundCount);

        address[] memory assetAdapters = new address[](fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            assetAdapters[i] = address(fund);
        }

        creditEnforcer.removeAssetAdapter(assetAdapters[removedFundIndex]);

        assertEq(creditEnforcer.assetAdapterLength(), fundCount - 1);

        CreditEnforcer.AssetAdapter memory assetAdapter = creditEnforcer
            .getAssetAdapter(assetAdapters[removedFundIndex]);
        assertEq(assetAdapter.set, false);
        assertEq(assetAdapter.index, 0);
    }

    function testremoveAssetAdapterExisting(
        uint8 fundCount,
        uint8 duplicateFundIndex
    ) external {
        vm.assume(fundCount < 10);
        vm.assume(duplicateFundIndex < fundCount);

        address[] memory assetAdapters = new address[](fundCount);

        for (uint256 i = 0; i < fundCount; i++) {
            MockAssetAdapter fund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(fund));
            assetAdapters[i] = address(fund);
        }

        creditEnforcer.removeAssetAdapter(assetAdapters[duplicateFundIndex]);

        vm.expectRevert("CE: adapter not set");
        creditEnforcer.removeAssetAdapter(assetAdapters[duplicateFundIndex]);
    }

    function testremoveAssetAdapterUnauthorized() external {
        MockAssetAdapter fund = new MockAssetAdapter();

        creditEnforcer.addAssetAdapter(address(fund));

        vm.expectRevert();
        vm.prank(eoa1);
        creditEnforcer.removeAssetAdapter(address(fund));
    }

    struct DurationWithValue {
        uint256 duration;
        uint128 value;
    }

    function testShortTermAssetsFuzz(
        uint256 ceDuration,
        DurationWithValue[] memory durationWithValue,
        uint128 psmValue
    ) external {
        vm.assume(durationWithValue.length < 6);

        creditEnforcer.setDuration(ceDuration);
        psm.setTotalValue(psmValue);

        uint256 expectedShortTermAssets = psmValue;

        for (uint256 i = 0; i < durationWithValue.length; i++) {
            uint256 duration = durationWithValue[i].duration;
            uint128 value = durationWithValue[i].value;
            MockAssetAdapter mockFund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(mockFund));
            mockFund.setDuration(duration);
            mockFund.setTotalValue(value);
            if (ceDuration > duration) {
                expectedShortTermAssets += value;
            }
        }

        assertEq(creditEnforcer.shortTermAssets(), expectedShortTermAssets);
    }

    function testExtendedAssetsFuzz(
        uint256 ceDuration,
        DurationWithValue[] memory durationWithValue
    ) external {
        vm.assume(durationWithValue.length < 6);

        creditEnforcer.setDuration(ceDuration);

        uint256 expectedExtendedAssets;

        for (uint256 i = 0; i < durationWithValue.length; i++) {
            uint256 duration = durationWithValue[i].duration;
            uint128 value = durationWithValue[i].value;
            MockAssetAdapter mockFund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(mockFund));
            mockFund.setDuration(duration);
            mockFund.setTotalValue(value);
            if (ceDuration < duration) {
                expectedExtendedAssets += value;
            }
        }

        assertEq(creditEnforcer.extendedAssets(), expectedExtendedAssets);
    }

    function testLiquidityRatioFuzz(
        uint128 ceDuration,
        DurationWithValue[] memory durationWithValue,
        uint128 psmValue,
        uint128 rusdTotalSupply,
        uint128 totalDebt
    ) external {
        vm.assume(durationWithValue.length < 6);

        rusd.setTotalSupply(rusdTotalSupply);
        termIssuer.setTotalDebt(totalDebt);

        creditEnforcer.setDuration(ceDuration);
        psm.setTotalValue(psmValue);

        uint256 expectedShortTermAssets = psmValue;

        for (uint256 i = 0; i < durationWithValue.length; i++) {
            uint256 duration = durationWithValue[i].duration;
            uint128 value = durationWithValue[i].value;
            MockAssetAdapter mockFund = new MockAssetAdapter();
            creditEnforcer.addAssetAdapter(address(mockFund));
            mockFund.setDuration(duration);
            mockFund.setTotalValue(value);
            if (ceDuration > duration) {
                expectedShortTermAssets += value;
            }
        }

        uint256 liquidityRatio = creditEnforcer.liquidityRatio();

        if (expectedShortTermAssets == 0) {
            assertEq(liquidityRatio, 0);
        } else if (creditEnforcer.liabilities() == 0) {
            assertEq(liquidityRatio, type(uint256).max);
        } else {
            uint256 expectedLiabilies = uint256(rusdTotalSupply) +
                uint256(totalDebt);

            uint256 expectedExtendedLiabilities;

            for (
                uint256 i = termIssuer.earliestID();
                i <= termIssuer.latestID();
                i++
            ) {
                if (
                    termIssuer.maturityTimestamp(i) >
                    block.timestamp + ceDuration
                ) {
                    expectedExtendedLiabilities += termIssuer.totalSupply(i);
                }
            }

            uint256 expectedShortTermLiabilities = expectedLiabilies -
                expectedExtendedLiabilities;

            assertEq(
                liquidityRatio,
                (expectedShortTermAssets * 1e6) / expectedShortTermLiabilities
            );
        }
    }

    function testLiquidityRatioHardCode() external {
        uint256 rusdTotalSupply = 1_000_000e18;
        uint256 totalDebt = 100_000e18;
        uint256 ceDuration = 30 days;

        rusd.setTotalSupply(rusdTotalSupply);
        termIssuer.setTotalDebt(totalDebt);

        creditEnforcer.setDuration(ceDuration);
        psm.setTotalValue(10_000_000e18);

        MockAssetAdapter mockAssetAdapter1 = new MockAssetAdapter();
        mockAssetAdapter1.setDuration(1 days);
        mockAssetAdapter1.setTotalValue(100_000e18);

        MockAssetAdapter mockAssetAdapter2 = new MockAssetAdapter();
        mockAssetAdapter2.setDuration(1 days);
        mockAssetAdapter2.setTotalValue(200_000e18);

        MockAssetAdapter mockAssetAdapter3 = new MockAssetAdapter();
        mockAssetAdapter3.setDuration(1 days);
        mockAssetAdapter3.setTotalValue(300_000e18);

        creditEnforcer.addAssetAdapter(address(mockAssetAdapter1));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter2));
        creditEnforcer.addAssetAdapter(address(mockAssetAdapter3));

        uint256 expectedLiabilies = uint256(rusdTotalSupply) +
            uint256(totalDebt);

        uint256 expectedExtendedLiabilities;

        for (
            uint256 i = termIssuer.earliestID();
            i <= termIssuer.latestID();
            i++
        ) {
            if (
                termIssuer.maturityTimestamp(i) > block.timestamp + ceDuration
            ) {
                expectedExtendedLiabilities += termIssuer.totalSupply(i);
            }
        }

        uint256 expectedShortTermLiabilities = expectedLiabilies -
            expectedExtendedLiabilities;

        assertEq(
            creditEnforcer.liquidityRatio(),
            ((psm.totalValue() +
                mockAssetAdapter1.totalValue() +
                mockAssetAdapter2.totalValue() +
                mockAssetAdapter3.totalValue()) * 1e6) /
                expectedShortTermLiabilities
        );

        mockAssetAdapter2.setDuration(100 days);

        assertEq(
            creditEnforcer.liquidityRatio(),
            ((psm.totalValue() +
                mockAssetAdapter1.totalValue() +
                mockAssetAdapter3.totalValue()) * 1e6) /
                expectedShortTermLiabilities
        );

        creditEnforcer.setDuration(101 days);

        assertEq(
            creditEnforcer.liquidityRatio(),
            ((psm.totalValue() +
                mockAssetAdapter1.totalValue() +
                mockAssetAdapter2.totalValue() +
                mockAssetAdapter3.totalValue()) * 1e6) /
                expectedShortTermLiabilities
        );

        mockAssetAdapter1.setDuration(200 days);
        mockAssetAdapter2.setDuration(200 days);
        mockAssetAdapter3.setDuration(200 days);

        assertEq(
            creditEnforcer.liquidityRatio(),
            (psm.totalValue() * 1e6) / expectedShortTermLiabilities
        );
    }

    function _checkPSMDebtMaxValid(uint256 amount) private {
        bool valid;
        string memory message;

        (valid, message) = creditEnforcer.checkPSMDebtMax(amount);

        assertTrue(valid);
        assertEq(message, "");
    }

    function _checkPSMDebtMaxInvalid(uint256 amount) private {
        bool valid;
        string memory message;

        (valid, message) = creditEnforcer.checkPSMDebtMax(amount);

        assertFalse(valid);
        assertEq(message, "CE: amount exceeds PSM debt max");
    }

    function _checkTermDebtMaxValid(uint256[2][3] memory data) private {
        bool valid;
        string memory message;

        uint256 length = data.length;
        for (uint256 i = 0; i < length; i++) {
            (valid, message) = creditEnforcer.checkTermDebtMax(
                data[i][0],
                data[i][1]
            );

            assertTrue(valid);
            assertEq(message, "");
        }
    }

    function _checkTermDebtMaxInvalid(uint256[2][3] memory data) private {
        bool valid;
        string memory message;

        uint256 length = data.length;
        for (uint256 i = 0; i < length; i++) {
            (valid, message) = creditEnforcer.checkTermDebtMax(
                data[i][0],
                data[i][1]
            );

            assertFalse(valid);
            assertEq(message, "CE: amount exceeds term minter debt max");
        }
    }
}
