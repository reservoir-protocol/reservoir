// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {Stablecoin} from "src/Stablecoin.sol";

import {PegStabilityModule} from "src/PegStabilityModule.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

contract MockStablecoin {
    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply;

    function setTotalSupply(uint256 supply) external {
        totalSupply = supply;
    }

    function mint(address account, uint256 amount) external {
        totalSupply += amount;
        balanceOf[account] += amount;
    }

    function burnFrom(address account, uint256 amount) public virtual {
        totalSupply -= amount;
        balanceOf[account] -= amount;
    }
}

contract PegStabilityModuleUnitTest is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    MockStablecoin rusd;
    ERC1967Proxy proxy;

    PegStabilityModule psm;

    uint256 public constant MAX_USDC_AMOUNT = 1e24;

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        rusd = new MockStablecoin();

        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );

        psm.grantRole(psm.MANAGER(), address(this));
        psm.grantRole(psm.SUPERVISOR(), address(this));

        psm.grantRole(psm.CONTROLLER(), address(this));
    }

    function testInitialState() external {
        assertEq(address(psm.underlyingPriceOracle()), address(usdcAggregator));
        assertEq(psm.underlyingRiskWeight(), 0);
        assertEq(address(psm.rusd()), address(rusd));
        assertEq(address(psm.underlying()), address(usdc));
        assertTrue(psm.hasRole(psm.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(psm.hasRole(psm.CONTROLLER(), address(this)));
    }

    function testAllocate(uint256 amount) external {
        usdc.mint(address(this), amount);

        assertEq(usdc.balanceOf(address(psm)), 0);

        usdc.approve(address(psm), amount);
        psm.allocate(amount);

        assertEq(usdc.balanceOf(address(psm)), amount);
        assertEq(usdc.balanceOf(address(this)), 0);
    }

    function testAllocateWithInsufficientAllowance(uint256 amount) external {
        vm.assume(amount > 0);

        usdc.mint(address(this), amount);

        vm.expectRevert("ERC20: insufficient allowance");
        psm.allocate(amount);
    }

    function testAllocateWithInsufficientBalance(uint256 amount) external {
        vm.assume(amount > 0);

        usdc.approve(address(psm), amount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        psm.allocate(amount);
    }

    function testWithdraw(
        uint256 allocateAmount,
        uint256 withdrawAmount
    ) external {
        vm.assume(allocateAmount >= withdrawAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(psm), allocateAmount);
        psm.allocate(allocateAmount);

        psm.withdraw(withdrawAmount);

        assertEq(usdc.balanceOf(address(psm)), allocateAmount - withdrawAmount);
        assertEq(usdc.balanceOf(address(this)), withdrawAmount);
    }

    function testWithdrawInsufficientBalance(
        uint256 allocateAmount,
        uint256 withdrawAmount
    ) external {
        vm.assume(allocateAmount < withdrawAmount);

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(psm), allocateAmount);
        psm.allocate(allocateAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        psm.withdraw(withdrawAmount);
    }

    function testWithdrawUnauthorized(
        uint256 allocateAmount,
        uint256 withdrawAmount,
        address wallet
    ) external {
        vm.assume(allocateAmount > 0 && withdrawAmount > 0);
        vm.assume(wallet != address(this));

        usdc.mint(address(this), allocateAmount);

        usdc.approve(address(psm), allocateAmount);
        psm.allocate(allocateAmount);

        vm.expectRevert();
        vm.prank(wallet);
        psm.withdraw(withdrawAmount);
    }

    function testMint(address from, address to, uint256 amountToPay) external {
        vm.assume(
            from != address(0) &&
                to != address(0) &&
                amountToPay < MAX_USDC_AMOUNT
        );
        vm.assume(from != address(psm) && to != address(psm));

        uint256 amountToRecieve = amountToPay * 1e12;

        usdc.mint(from, amountToPay);

        vm.prank(from);
        usdc.approve(address(psm), amountToPay);

        psm.mint(from, to, amountToPay);

        assertEq(usdc.balanceOf(address(psm)), amountToPay);
        assertEq(usdc.balanceOf(address(from)), 0);
        assertEq(usdc.balanceOf(address(to)), 0);

        assertEq(rusd.balanceOf(address(psm)), 0);
        if (from == to) {
            assertEq(rusd.balanceOf(address(from)), amountToRecieve);
        } else {
            assertEq(rusd.balanceOf(address(from)), 0);
        }
        assertEq(rusd.balanceOf(address(to)), amountToRecieve);
    }

    function testMintWithInsufficientAllowance(
        address from,
        address to,
        uint256 amountToPay
    ) external {
        vm.assume(
            from != address(0) &&
                to != address(0) &&
                amountToPay < MAX_USDC_AMOUNT &&
                amountToPay > 0
        );

        usdc.mint(from, amountToPay);

        vm.expectRevert("ERC20: insufficient allowance");
        psm.mint(from, to, amountToPay);
    }

    function testMintWithInsufficientBalance(
        address from,
        address to,
        uint256 amountToPay
    ) external {
        vm.assume(
            from != address(0) &&
                to != address(0) &&
                amountToPay < MAX_USDC_AMOUNT &&
                amountToPay > 0
        );

        vm.prank(from);
        usdc.approve(address(psm), amountToPay);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        psm.mint(from, to, amountToPay);
    }

    function testMintUnauthorized(address wallet, uint256 amount) external {
        vm.assume(wallet != address(0));
        vm.assume(wallet != address(this));

        usdc.mint(wallet, amount);

        vm.prank(wallet);
        usdc.approve(address(psm), amount);

        vm.prank(wallet);
        vm.expectRevert();
        psm.mint(wallet, wallet, amount);
    }

    function testRedeem(
        uint256 mintAmountInUSDC,
        uint256 redeemAmountInUSDC
    ) external {
        vm.assume(mintAmountInUSDC < MAX_USDC_AMOUNT);
        vm.assume(redeemAmountInUSDC <= mintAmountInUSDC);

        usdc.mint(address(this), mintAmountInUSDC);

        usdc.approve(address(psm), mintAmountInUSDC);

        psm.mint(address(this), address(this), mintAmountInUSDC);

        psm.redeem(redeemAmountInUSDC);

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmountInUSDC - redeemAmountInUSDC
        );
        assertEq(usdc.balanceOf(address(this)), redeemAmountInUSDC);

        assertEq(rusd.balanceOf(address(psm)), 0);
        assertEq(
            rusd.balanceOf(address(this)),
            (mintAmountInUSDC - redeemAmountInUSDC) * 1e12
        );
    }

    function testRedeemOnPaused(address to, uint256 amount) external {
        vm.assume(to != address(0) && amount < MAX_USDC_AMOUNT);

        psm.pause();

        vm.expectRevert("Pausable: paused");
        psm.redeem(to, amount);
    }

    function testRedeemWithTo(
        uint256 mintAmountInUSDC,
        uint256 redeemAmountInUSDC,
        address to
    ) external {
        vm.assume(mintAmountInUSDC < MAX_USDC_AMOUNT);
        vm.assume(redeemAmountInUSDC <= mintAmountInUSDC);
        vm.assume(
            to != address(0) && to != address(psm) && to != address(this)
        );

        usdc.mint(address(this), mintAmountInUSDC);

        usdc.approve(address(psm), mintAmountInUSDC);

        psm.mint(address(this), address(this), mintAmountInUSDC);

        psm.redeem(to, redeemAmountInUSDC);

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmountInUSDC - redeemAmountInUSDC
        );
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(to), redeemAmountInUSDC);

        assertEq(rusd.balanceOf(address(psm)), 0);
        assertEq(
            rusd.balanceOf(address(this)),
            (mintAmountInUSDC - redeemAmountInUSDC) * 1e12
        );
        assertEq(rusd.balanceOf(to), 0);
    }

    function testSetUndelyingRiskWeight(uint256 riskWeight) external {
        if (riskWeight < 1e6) {
            psm.setUnderlyingRiskWeight(riskWeight);
            assertEq(psm.underlyingRiskWeight(), riskWeight);
        } else {
            vm.expectRevert("PSM: Risk Weight can not be above 100%");
            psm.setUnderlyingRiskWeight(riskWeight);
        }
    }

    function testSetUSDCRiskWeightUnauthorized(
        uint256 riskWeight,
        address wallet
    ) external {
        vm.assume(wallet != address(this));
        vm.assume(riskWeight < 1e6);

        vm.prank(wallet);
        vm.expectRevert();
        psm.setUnderlyingRiskWeight(riskWeight);
    }

    function testTotalValue(uint256 amount) external {
        vm.assume(amount < MAX_USDC_AMOUNT);

        usdc.mint(address(this), amount);

        usdc.approve(address(psm), amount);
        psm.allocate(amount);

        assertEq(usdc.balanceOf(address(psm)), amount);
        assertEq(
            psm.totalValue(),
            uint256(usdcAggregator.latestAnswer()) * amount * 1e4
        );
    }

    function testUnderlyingTotalValue(uint256 amount) external {
        vm.assume(amount < MAX_USDC_AMOUNT);

        usdc.mint(address(this), amount);

        usdc.approve(address(psm), amount);
        psm.allocate(amount);

        assertEq(usdc.balanceOf(address(psm)), amount);
        assertEq(
            psm.underlyingTotalValue(),
            uint256(usdcAggregator.latestAnswer()) * amount * 1e4
        );
    }

    function testTotalRiskValue(
        uint256 amount,
        uint256 riskWeightValue
    ) external {
        vm.assume(amount < MAX_USDC_AMOUNT);
        vm.assume(riskWeightValue < 1e6);

        usdc.mint(address(this), amount);

        usdc.approve(address(psm), amount);
        psm.allocate(amount);

        psm.setUnderlyingRiskWeight(riskWeightValue);

        assertEq(
            psm.totalRiskValue(),
            (uint256(usdcAggregator.latestAnswer()) *
                amount *
                1e4 *
                riskWeightValue) / 1e6
        );
    }

    function testUnderlyingTotalRiskValue(
        uint256 amount,
        uint256 riskWeightValue
    ) external {
        vm.assume(amount < MAX_USDC_AMOUNT);
        vm.assume(riskWeightValue < 1e6);

        usdc.mint(address(this), amount);

        usdc.approve(address(psm), amount);
        psm.allocate(amount);

        psm.setUnderlyingRiskWeight(riskWeightValue);

        assertEq(
            psm.underlyingTotalRiskValue(),
            (uint256(usdcAggregator.latestAnswer()) *
                amount *
                1e4 *
                riskWeightValue) / 1e6
        );
    }

    function testUnderlyingRiskValue(
        uint256 amount,
        uint256 riskWeightValue
    ) external {
        vm.assume(amount < MAX_USDC_AMOUNT);
        vm.assume(riskWeightValue < 1e6);

        psm.setUnderlyingRiskWeight(riskWeightValue);

        assertEq(
            psm.underlyingRiskValue(amount),
            (uint256(usdcAggregator.latestAnswer()) *
                amount *
                1e4 *
                riskWeightValue) / 1e6
        );
    }

    function testUnderlyingValue(uint256 amount) external {
        vm.assume(amount < MAX_USDC_AMOUNT);

        assertEq(
            psm.underlyingValue(amount),
            uint256(usdcAggregator.latestAnswer()) * amount * 1e4
        );
    }

    function testUnderlyingBalance(uint256 amount) external {
        vm.assume(amount < MAX_USDC_AMOUNT);

        usdc.mint(address(psm), amount);

        assertEq(psm.underlyingBalance(), usdc.balanceOf(address(psm)));
    }

    function testPause() external {
        psm.pause();
        assertTrue(psm.paused());
    }

    function testUnpause() external {
        psm.pause();
        psm.unpause();
        assertFalse(psm.paused());
    }

    function testPauseUnauthorized(address wallet) external {
        vm.assume(wallet != address(this));

        vm.prank(wallet);
        vm.expectRevert();
        psm.pause();
    }

    function testUnpauseUnauthorized(address wallet) external {
        vm.assume(wallet != address(this));

        psm.pause();

        vm.prank(wallet);
        vm.expectRevert();
        psm.unpause();
    }
}
