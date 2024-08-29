// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {Stablecoin} from "src/Stablecoin.sol";
import {Savingcoin} from "src/Savingcoin.sol";

import {SavingModule} from "src/SavingModule.sol";

import {IToken} from "src/interfaces/IToken.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

contract SavingModuleTest is Test {
    Stablecoin rusd;
    Savingcoin srusd;

    SavingModule sm;

    address immutable eoa1 = vm.addr(1);
    address immutable eoa2 = vm.addr(2);
    address immutable eoa3 = vm.addr(3);
    address immutable eoa4 = vm.addr(4);
    address immutable eoa5 = vm.addr(5);
    address immutable eoa6 = vm.addr(6);

    function setUp() external {
        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        srusd = new Savingcoin(address(this), "Savings rUSD", "srUSD");

        sm = new SavingModule(
            address(this),
            IToken(address(rusd)),
            IToken(address(srusd))
        );

        sm.grantRole(sm.MANAGER(), address(this));
        sm.grantRole(sm.CONTROLLER(), address(this));

        rusd.grantRole(rusd.MINTER(), address(sm));
        srusd.grantRole(srusd.MINTER(), address(sm));

        rusd.grantRole(rusd.MINTER(), address(this));
        srusd.grantRole(srusd.MINTER(), address(this));
    }

    function testInitialState() external {
        assertTrue(sm.hasRole(0x00, address(this)));

        assertTrue(sm.hasRole(sm.MANAGER(), address(this)));
        assertTrue(sm.hasRole(sm.CONTROLLER(), address(this)));

        assertEq(sm.lastTimestamp(), 1);

        assertEq(address(sm.rusd()), address(rusd));
        assertEq(address(sm.srusd()), address(srusd));

        assertEq(sm.currentRate(), 0e12);
        assertEq(sm.compoundFactor(), 1e8);

        assertEq(sm.currentPrice(), 1e8);
    }

    function testMint() external {
        rusd.mint(eoa1, 2_000_000e18);
        rusd.mint(eoa2, 2_000_000e18);
        rusd.mint(eoa3, 2_000_000e18);
        rusd.mint(eoa4, 2_000_000e18);
        rusd.mint(eoa5, 2_000_000e18);
        rusd.mint(eoa6, 2_000_000e18);

        vm.prank(eoa1);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa3);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa4);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa5);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa6);
        rusd.approve(address(sm), type(uint256).max);

        assertEq(sm.currentPrice(), 1e8);

        assertEq(srusd.totalSupply(), 0);
        assertEq(sm.rusdTotalLiability(), 12_000_000.0e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        assertApproxEqRel(sm.previewMint(500_000e18), 500_000e18, 0.0001e18);

        sm.mint(eoa1, eoa1, 500_000e18);
        sm.mint(eoa1, address(this), 500_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa1), 500_000.0e18, 0.0001e18);
        assertApproxEqRel(
            srusd.balanceOf(address(this)),
            500_000.0e18,
            0.0001e18
        );

        assertApproxEqRel(srusd.totalSupply(), 1_000_000.0e18, 0.0001e18);

        assertEq(rusd.balanceOf(eoa1), 1_000_000e18);
        assertEq(rusd.totalSupply(), 11_000_000e18);

        assertApproxEqRel(sm.rusdTotalLiability(), 12_000_000.0e18, 0.0001e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000135537418e12); // ~5% APR

        assertEq(sm.currentRate(), 0.000135537418e12);
        assertEq(sm.currentPrice(), 1e8);

        vm.warp(block.timestamp + 360 days);

        assertEq(sm.currentPrice(), 1.04999976e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        assertApproxEqRel(
            sm.previewMint(500_000e18),
            476_190.585e18,
            0.0001e18
        );

        sm.mint(eoa3, eoa3, 500_000e18);
        sm.mint(eoa3, address(this), 500_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa3), 476_190.585e18, 0.0001e18);
        assertApproxEqRel(
            srusd.balanceOf(address(this)),
            976_190.4761e18,
            0.0001e18
        );

        assertApproxEqRel(srusd.totalSupply(), 1_952_380.9523e18, 0.0001e18);

        assertEq(rusd.balanceOf(eoa3), 1_000_000e18);
        assertEq(rusd.totalSupply(), 10_000_000e18);

        assertApproxEqRel(
            sm.rusdTotalLiability(),
            12_049_999.9999e18,
            0.0001e18
        );

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000264785549e12); // ~10% APR

        assertEq(sm.currentRate(), 0.000264785549e12);
        assertEq(sm.currentPrice(), 1.04999976e8);

        vm.warp(block.timestamp + 180 days);

        assertEq(sm.currentPrice(), 1.10124880e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        assertApproxEqRel(
            sm.previewMint(500_000e18),
            454_030.0066e18,
            0.0001e18
        );

        sm.mint(eoa6, eoa6, 500_000e18);
        sm.mint(eoa6, address(this), 500_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa6), 454_030.0066e18, 0.0001e18);
        assertApproxEqRel(
            srusd.balanceOf(address(this)),
            1_430_220.5916e18,
            0.0001e18
        );

        assertApproxEqRel(srusd.totalSupply(), 2_860_441.1833e18, 0.0001e18);

        assertEq(rusd.balanceOf(eoa6), 1_000_000e18);
        assertEq(rusd.totalSupply(), 9_000_000e18);

        assertApproxEqRel(
            sm.rusdTotalLiability(),
            12_150_057.4206e18,
            0.0001e18
        );

        assertEq(sm.totalDebt(), srusd.totalSupply());
    }

    function testRedeem() external {
        srusd.mint(eoa1, 2_000_000e18);
        srusd.mint(eoa2, 2_000_000e18);
        srusd.mint(eoa3, 2_000_000e18);
        srusd.mint(eoa4, 2_000_000e18);
        srusd.mint(eoa5, 2_000_000e18);
        srusd.mint(eoa6, 2_000_000e18);

        vm.prank(eoa1);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa2);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa3);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa4);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa5);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa6);
        srusd.approve(address(sm), type(uint256).max);

        assertEq(sm.currentPrice(), 1e8);

        assertEq(rusd.totalSupply(), 0);
        assertEq(sm.rusdTotalLiability(), 12_000_000e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa1);
        sm.redeem(500_000e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa1);
        sm.redeem(address(this), 500_000e18);

        assertEq(rusd.balanceOf(eoa1), 500_000e18);
        assertEq(rusd.balanceOf(address(this)), 500_000e18);

        assertEq(rusd.totalSupply(), 1_000_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa1), 1_000_000.0e18, 0.0001e18);
        assertApproxEqRel(srusd.totalSupply(), 11_000_000.0e18, 0.0001e18);

        assertApproxEqRel(sm.rusdTotalLiability(), 12_000_000.0e18, 0.0001e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000135537418e12); // ~5% APR

        assertEq(sm.currentRate(), 0.000135537418e12);
        assertEq(sm.currentPrice(), 1e8);

        vm.warp(block.timestamp + 360 days);

        assertEq(sm.currentPrice(), 1.04999976e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa3);
        sm.redeem(500_000e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa3);
        sm.redeem(address(this), 500_000e18);

        assertEq(rusd.balanceOf(eoa3), 500_000e18);
        assertEq(rusd.balanceOf(address(this)), 1_000_000e18);

        assertEq(rusd.totalSupply(), 2_000_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa3), 1_047_619.0476e18, 0.0001e18);
        assertApproxEqRel(srusd.totalSupply(), 10_047_619.0476e18, 0.0001e18);

        assertApproxEqRel(sm.rusdTotalLiability(), 12_550_000.0e18, 0.0001e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000264785549e12); // ~10% APR

        assertEq(sm.currentRate(), 0.000264785549e12);
        assertEq(sm.currentPrice(), 1.04999976e8);

        vm.warp(block.timestamp + 180 days);

        assertEq(sm.currentPrice(), 1.10124880e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa6);
        sm.redeem(500_000e18);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        vm.prank(eoa6);
        sm.redeem(address(this), 500_000e18);

        assertEq(rusd.balanceOf(eoa6), 500_000e18);
        assertEq(rusd.balanceOf(address(this)), 1_500_000e18);

        assertEq(rusd.totalSupply(), 3_000_000e18);

        assertApproxEqRel(srusd.balanceOf(eoa6), 1_091_939.9866e18, 0.0001e18);

        assertApproxEqRel(srusd.totalSupply(), 9_139_558.8166e18, 0.0001e18);

        assertApproxEqRel(
            sm.rusdTotalLiability(),
            13_064_928.1793e18,
            0.0001e18
        );

        assertEq(sm.totalDebt(), srusd.totalSupply());
    }

    function testUpdate() external {
        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.0e12); // 0% APR

        assertEq(sm.currentRate(), 0);
        assertEq(sm.currentPrice(), 1e8);

        vm.warp(block.timestamp + 360 days);

        assertEq(sm.currentPrice(), 1e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000135537418e12); // ~5% APR

        assertEq(sm.currentRate(), 0.000135537418e12);
        assertEq(sm.currentPrice(), 1e8);

        vm.warp(block.timestamp + 360 days);

        assertEq(sm.currentPrice(), 1.04999976e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());

        sm.update(0.000264785549e12); // ~10% APR

        assertEq(sm.currentRate(), 0.000264785549e12);
        assertEq(sm.currentPrice(), 1.04999976e8);

        vm.warp(block.timestamp + 360 days);

        assertEq(sm.currentPrice(), 1.15499611e8);

        assertEq(sm.totalDebt(), srusd.totalSupply());
    }

    function testMintBounds() external {
        uint256 burnAmount;
        uint256 mintAmount;

        rusd.mint(eoa1, 2_000_000e18);
        rusd.mint(eoa2, 2_000_000e18);
        rusd.mint(eoa3, 2_000_000e18);
        rusd.mint(eoa4, 2_000_000e18);

        vm.prank(eoa1);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa3);
        rusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa4);
        rusd.approve(address(sm), type(uint256).max);

        sm.update(0.000133680617e12); // ~5% APR

        vm.warp(block.timestamp + 365 days);

        assertEq(sm.currentPrice(), 1.04999976e8);
        assertEq(sm.currentRate(), 0.000133680617e12);

        sm.mint(eoa1, eoa1, 0);

        mintAmount = srusd.balanceOf(eoa1);
        burnAmount = 2_000_000e18 - rusd.balanceOf(eoa1);

        assertEq(burnAmount, 0);
        assertEq(mintAmount, 0);

        assertGe(0, (mintAmount * sm.currentPrice()) / 1e8);

        sm.mint(eoa2, eoa2, 2);

        mintAmount = srusd.balanceOf(eoa2);
        burnAmount = 2_000_000e18 - rusd.balanceOf(eoa2);

        assertEq(burnAmount, 2);
        assertEq(mintAmount, 1);

        assertGe(2, (mintAmount * sm.currentPrice()) / 1e8);

        sm.update(0.001111480547e12); // ~50% APR

        vm.warp(block.timestamp + 365 days);

        assertEq(sm.currentPrice(), 1.57373374e8);
        assertEq(sm.currentRate(), 0.001111480547e12);

        sm.mint(eoa3, eoa3, 4);

        mintAmount = srusd.balanceOf(eoa3);
        burnAmount = 2_000_000e18 - rusd.balanceOf(eoa3);

        assertEq(burnAmount, 4);
        assertEq(mintAmount, 2);

        assertGe(4, (mintAmount * sm.currentPrice()) / 1e8);

        sm.mint(eoa4, eoa4, 8);

        mintAmount = srusd.balanceOf(eoa4);
        burnAmount = 2_000_000e18 - rusd.balanceOf(eoa4);

        assertEq(burnAmount, 8);
        assertEq(mintAmount, 5);

        assertGe(8, (mintAmount * sm.currentPrice()) / 1e8);
    }

    function testRedeemBounds() external {
        uint256 burnAmount;

        srusd.mint(eoa1, 2_000_000e18);
        srusd.mint(eoa2, 2_000_000e18);
        srusd.mint(eoa3, 2_000_000e18);
        srusd.mint(eoa4, 2_000_000e18);

        vm.prank(eoa1);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa2);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa3);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa4);
        srusd.approve(address(sm), type(uint256).max);

        sm.update(0.000133680617e12); // ~5% APR

        vm.warp(block.timestamp + 365 days);

        assertEq(sm.currentPrice(), 1.04999976e8);
        assertEq(sm.currentRate(), 0.000133680617e12);

        vm.prank(eoa1);
        sm.redeem(0);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa1);

        assertEq(burnAmount, 0);
        assertEq(rusd.balanceOf(eoa1), 0);

        assertGe((burnAmount * sm.currentPrice()) / 1e8, 0);

        vm.prank(eoa2);
        sm.redeem(2);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa2);

        assertEq(burnAmount, 2);
        assertEq(rusd.balanceOf(eoa2), 2);

        assertGe((burnAmount * sm.currentPrice()) / 1e8, 2);

        sm.update(0.001111480547e12); // ~50% APR

        vm.warp(block.timestamp + 365 days);

        assertEq(sm.currentPrice(), 1.57373374e8);
        assertEq(sm.currentRate(), 0.001111480547e12);

        vm.prank(eoa3);
        sm.redeem(4);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa3);

        assertEq(burnAmount, 3);
        assertEq(rusd.balanceOf(eoa3), 4);

        assertGe((burnAmount * sm.currentPrice()) / 1e8, 4);

        vm.prank(eoa4);
        sm.redeem(8);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa4);

        assertEq(burnAmount, 6);
        assertEq(rusd.balanceOf(eoa4), 8);

        assertGe((burnAmount * sm.currentPrice()) / 1e8, 8);
    }

    function testRedeemFee() external {
        uint256 burnAmount;

        srusd.mint(eoa1, 2_000_000e18);
        srusd.mint(eoa2, 2_000_000e18);
        srusd.mint(eoa3, 2_000_000e18);
        srusd.mint(eoa4, 2_000_000e18);

        vm.prank(eoa1);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa2);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa3);
        srusd.approve(address(sm), type(uint256).max);

        vm.prank(eoa4);
        srusd.approve(address(sm), type(uint256).max);

        sm.update(0.001900837677e12); // ~100% APR

        vm.warp(block.timestamp + 365 days);

        assertEq(sm.currentPrice(), 1.98903535e8);
        assertEq(sm.currentRate(), 0.001900837677e12);

        assertEq(sm.redeemFee(), 0e6);

        vm.prank(eoa1);
        sm.redeem(100e18);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa1);

        assertApproxEqRel(burnAmount, 50.2756e18, 0.0001e18);

        sm.setRedeemFee(1e4);

        assertEq(sm.redeemFee(), 1e4);

        vm.prank(eoa2);
        sm.redeem(100e18);

        burnAmount = 2_000_000e18 - srusd.balanceOf(eoa2);

        assertApproxEqRel(burnAmount, 50.7783e18, 0.0001e18);

        assertEq(
            srusd.balanceOf(eoa1) - srusd.balanceOf(eoa2),
            (sm.previewRedeem(100e18) * sm.redeemFee()) / 1e6
        );
    }

    function testSetRedeemFee(uint64 fee) external {
        if (fee >= 1e6) {
            vm.expectRevert("SM: Fee can not be above 100%");
            sm.setRedeemFee(fee);
        } else {
            sm.setRedeemFee(fee);
            assertEq(sm.redeemFee(), fee);
        }
    }

    function testUpdateInvalid(uint64 rate) external {
        vm.assume(rate >= 1e12);

        vm.expectRevert("SM: Savings rate can not be above 100% per anum");
        sm.update(rate);
    }
}
