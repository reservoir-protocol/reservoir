// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {Stablecoin} from "src/Stablecoin.sol";

import {PegStabilityModule} from "src/PegStabilityModule.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

contract PegStabilityModuleTest is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    Stablecoin rusd;

    PegStabilityModule psm;

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        psm.grantRole(psm.CONTROLLER(), address(this));
        psm.grantRole(psm.SUPERVISOR(), address(this));

        rusd.grantRole(rusd.MINTER(), address(psm));
    }

    function testInitialState() external {
        assertTrue(psm.hasRole(psm.SUPERVISOR(), address(this)));

        assertTrue(psm.hasRole(0x00, address(this)));
        assertTrue(psm.hasRole(psm.CONTROLLER(), address(this)));

        assertEq(address(psm.rusd()), address(rusd));

        assertEq(address(psm.underlyingPriceOracle()), address(usdcAggregator));

        assertEq(psm.underlyingRiskWeight(), 0);
    }

    function testTransfer() external {
        bytes memory encodedSelector;

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(psm), type(uint256).max);

        psm.allocate(1_000_000e6);

        assertEq(psm.underlyingBalance(), 1_000_000e6);
        assertEq(usdc.balanceOf(address(this)), 0);

        psm.withdraw(1_000_000e6);

        assertEq(psm.underlyingBalance(), 0);
        assertEq(usdc.balanceOf(address(this)), 1_000_000e6);
    }

    function testUSDCValue() external {
        assertEq(usdcAggregator.latestAnswer(), 1e8);

        assertEq(psm.underlyingValue(0), 0);
        assertEq(psm.underlyingValue(1_000_000e6), 1_000_000e18);

        usdcAggregator.updateAnswer(95_000_000);

        assertEq(psm.underlyingValue(0), 0);
        assertEq(psm.underlyingValue(1_000_000e6), 950_000e18);

        usdcAggregator.updateAnswer(105_000_000);

        assertEq(psm.underlyingValue(0), 0);
        assertEq(psm.underlyingValue(1_000_000e6), 1_050_000e18);
    }

    function testMint() external {
        uint256 usdcBalance = 0;
        bytes memory encodedSelector;

        address eoa1 = vm.addr(1);
        address eoa2 = vm.addr(2);
        address eoa3 = vm.addr(3);
        address eoa4 = vm.addr(4);
        address eoa5 = vm.addr(5);
        address eoa6 = vm.addr(6);

        usdc.mint(eoa1, 2_000_000e6);
        usdc.mint(eoa2, 2_000_000e6);
        usdc.mint(eoa3, 2_000_000e6);
        usdc.mint(eoa4, 2_000_000e6);
        usdc.mint(eoa5, 2_000_000e6);
        usdc.mint(eoa6, 2_000_000e6);

        vm.prank(eoa1);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa3);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa4);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa5);
        usdc.approve(address(psm), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(psm), type(uint256).max);

        assertEq(usdcAggregator.latestAnswer(), 1e8);

        psm.mint(eoa1, eoa1, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa1), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa1), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa1);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdcAggregator.updateAnswer(95_000_000);

        psm.mint(eoa2, eoa2, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa2), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa2), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa2);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdcAggregator.updateAnswer(105_000_000);

        psm.mint(eoa3, eoa3, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa2), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa3), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa3);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdcAggregator.updateAnswer(100_000_000);

        psm.mint(eoa4, eoa4, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa4), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa4), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa4);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdcAggregator.updateAnswer(95_000_000);

        psm.mint(eoa5, eoa5, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa5), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa5), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa5);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdcAggregator.updateAnswer(105_000_000);

        psm.mint(eoa6, eoa6, 1_000_000e6);

        assertEq(rusd.balanceOf(eoa6), 1_000_000e18);
        assertEq(usdc.balanceOf(eoa4), 1_000_000e6);

        usdcBalance += 2_000_000e6 - usdc.balanceOf(eoa6);

        assertEq(psm.underlyingBalance(), usdcBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(usdcBalance));

        usdc.mint(address(this), 2_000_000e6);
        usdc.approve(address(psm), type(uint256).max);

        usdcAggregator.updateAnswer(100_000_000);
    }

    function testRedeem() external {
        uint256 usdcBalance = 0;
        uint256 remainingBalance = 0;

        bytes memory encodedSelector;

        address eoa1 = vm.addr(1);
        address eoa2 = vm.addr(2);
        address eoa3 = vm.addr(3);
        address eoa4 = vm.addr(4);
        address eoa5 = vm.addr(5);
        address eoa6 = vm.addr(6);

        vm.prank(eoa1);
        rusd.approve(address(psm), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(psm), type(uint256).max);

        vm.prank(eoa3);
        rusd.approve(address(psm), type(uint256).max);

        vm.prank(eoa4);
        rusd.approve(address(psm), type(uint256).max);

        vm.prank(eoa5);
        rusd.approve(address(psm), type(uint256).max);

        vm.prank(eoa6);
        rusd.approve(address(psm), type(uint256).max);

        usdc.mint(address(this), 6_000_000e6);
        usdc.approve(address(psm), type(uint256).max);

        psm.mint(address(this), eoa1, 1_000_000e6);
        psm.mint(address(this), eoa2, 1_000_000e6);
        psm.mint(address(this), eoa3, 1_000_000e6);
        psm.mint(address(this), eoa4, 1_000_000e6);
        psm.mint(address(this), eoa5, 1_000_000e6);
        psm.mint(address(this), eoa6, 1_000_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdcAggregator.latestAnswer(), 1e8);

        remainingBalance = 6_000_000e6;

        assertEq(psm.underlyingBalance(), remainingBalance);
        assertEq(psm.totalValue(), psm.underlyingValue(remainingBalance));

        vm.prank(eoa1);
        psm.redeem(500_000e6);

        vm.prank(eoa1);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa1), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa1);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        usdcAggregator.updateAnswer(95_000_000);

        vm.prank(eoa2);
        psm.redeem(500_000e6);

        vm.prank(eoa2);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa2), 0);
        assertEq(usdc.balanceOf(eoa2), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa2);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        usdcAggregator.updateAnswer(105_000_000);

        vm.prank(eoa3);
        psm.redeem(500_000e6);

        vm.prank(eoa3);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa3), 0);
        assertEq(usdc.balanceOf(eoa3), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa3);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        usdcAggregator.updateAnswer(100_000_000);

        vm.prank(eoa4);
        psm.redeem(500_000e6);

        vm.prank(eoa4);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa4), 0);
        assertEq(usdc.balanceOf(eoa4), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa4);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        usdcAggregator.updateAnswer(95_000_000);

        vm.prank(eoa5);
        psm.redeem(500_000e6);

        vm.prank(eoa5);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa5), 0);
        assertEq(usdc.balanceOf(eoa5), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa5);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        usdcAggregator.updateAnswer(105_000_000);

        vm.prank(eoa6);
        psm.redeem(500_000e6);

        vm.prank(eoa6);
        psm.redeem(address(this), 500_000e6);

        usdcBalance += 500_000e6;

        assertEq(rusd.balanceOf(eoa6), 0);
        assertEq(usdc.balanceOf(eoa6), 500_000e6);

        assertEq(rusd.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), usdcBalance);

        remainingBalance -= usdc.balanceOf(eoa6);

        assertEq(psm.underlyingBalance(), remainingBalance - usdcBalance);
        assertEq(
            psm.totalValue(),
            psm.underlyingValue(remainingBalance - usdcBalance)
        );

        psm.mint(address(this), address(this), 1_000_000e6);
        rusd.approve(address(psm), type(uint256).max);

        usdcAggregator.updateAnswer(100_000_000);
    }
}
