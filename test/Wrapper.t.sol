// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Wrapper} from "src/Wrapper.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract WrapperTest is Test {
    Wrapper wrapper;
    Stablecoin rusd;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function setUp() external {
        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");
        wrapper = new Wrapper("Wrapped Reservoir Stablecoin", "wrUSD", rusd);

        rusd.grantRole(rusd.MINTER(), address(this));

        rusd.mint(eoa1, 1_000e18);
        rusd.mint(eoa2, 1_000e18);

        vm.prank(eoa1);
        rusd.approve(address(wrapper), type(uint256).max);

        vm.prank(eoa2);
        rusd.approve(address(wrapper), type(uint256).max);
    }

    function testInitialState() external {
        assertEq(wrapper.symbol(), "wrUSD");
        assertEq(wrapper.name(), "Wrapped Reservoir Stablecoin");

        assertEq(wrapper.decimals(), 18);
        assertEq(wrapper.asset(), address(rusd));

        assertEq(wrapper.totalAssets(), 0);
        assertEq(wrapper.totalSupply(), 0);

        assertEq(rusd.balanceOf(eoa1), 1_000e18);
        assertEq(rusd.balanceOf(eoa2), 1_000e18);

        assertEq(rusd.totalSupply(), 2_000e18);
    }

    function testMint() external {
        assertEq(wrapper.previewMint(12e18), 12e18);
        assertEq(wrapper.previewMint(24e18), 24e18);
        assertEq(wrapper.previewMint(76e18), 76e18);
        assertEq(wrapper.previewMint(88e18), 88e18);
        assertEq(wrapper.previewMint(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.mint(12e18, eoa1);

        vm.prank(eoa2);
        wrapper.mint(24e18, eoa2);

        assertEq(rusd.balanceOf(eoa1), 988e18);
        assertEq(rusd.balanceOf(eoa2), 976e18);

        assertEq(wrapper.balanceOf(eoa1), 12e18);
        assertEq(wrapper.balanceOf(eoa2), 24e18);

        assertEq(wrapper.totalSupply(), 36e18);
        assertEq(wrapper.totalAssets(), 36e18);

        assertEq(wrapper.previewMint(12e18), 12e18);
        assertEq(wrapper.previewMint(24e18), 24e18);
        assertEq(wrapper.previewMint(76e18), 76e18);
        assertEq(wrapper.previewMint(88e18), 88e18);
        assertEq(wrapper.previewMint(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.mint(76e18, eoa2);

        vm.prank(eoa2);
        wrapper.mint(100e18, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 12e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 212e18);
        assertEq(wrapper.totalAssets(), 212e18);

        assertEq(wrapper.previewMint(12e18), 12e18);
        assertEq(wrapper.previewMint(24e18), 24e18);
        assertEq(wrapper.previewMint(76e18), 76e18);
        assertEq(wrapper.previewMint(88e18), 88e18);
        assertEq(wrapper.previewMint(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.mint(100e18, eoa1);

        vm.prank(eoa2);
        wrapper.mint(88e18, eoa1);

        assertEq(wrapper.balanceOf(eoa1), 200e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 400e18);
        assertEq(wrapper.totalAssets(), 400e18);
    }

    function testDeposit() external {
        assertEq(wrapper.previewDeposit(12e18), 12e18);
        assertEq(wrapper.previewDeposit(24e18), 24e18);
        assertEq(wrapper.previewDeposit(76e18), 76e18);
        assertEq(wrapper.previewDeposit(88e18), 88e18);
        assertEq(wrapper.previewDeposit(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.deposit(12e18, eoa1);

        vm.prank(eoa2);
        wrapper.deposit(24e18, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 12e18);
        assertEq(wrapper.balanceOf(eoa2), 24e18);

        assertEq(wrapper.totalSupply(), 36e18);
        assertEq(wrapper.totalAssets(), 36e18);

        assertEq(wrapper.previewDeposit(12e18), 12e18);
        assertEq(wrapper.previewDeposit(24e18), 24e18);
        assertEq(wrapper.previewDeposit(76e18), 76e18);
        assertEq(wrapper.previewDeposit(88e18), 88e18);
        assertEq(wrapper.previewDeposit(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.deposit(76e18, eoa2);

        vm.prank(eoa2);
        wrapper.deposit(100e18, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 12e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 212e18);
        assertEq(wrapper.totalAssets(), 212e18);

        assertEq(wrapper.previewDeposit(12e18), 12e18);
        assertEq(wrapper.previewDeposit(24e18), 24e18);
        assertEq(wrapper.previewDeposit(76e18), 76e18);
        assertEq(wrapper.previewDeposit(88e18), 88e18);
        assertEq(wrapper.previewDeposit(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.deposit(100e18, eoa1);

        vm.prank(eoa2);
        wrapper.deposit(88e18, eoa1);

        assertEq(wrapper.balanceOf(eoa1), 200e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 400e18);
        assertEq(wrapper.totalAssets(), 400e18);
    }

    function testWithdraw() external {
        vm.prank(eoa1);
        wrapper.mint(100e18, eoa1);

        vm.prank(eoa2);
        wrapper.mint(100e18, eoa2);

        vm.prank(eoa1);
        wrapper.deposit(100e18, eoa2);

        vm.prank(eoa2);
        wrapper.deposit(100e18, eoa1);

        assertEq(wrapper.balanceOf(eoa1), 200e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 400e18);
        assertEq(wrapper.totalAssets(), 400e18);

        assertEq(wrapper.previewWithdraw(10e18), 10e18);
        assertEq(wrapper.previewWithdraw(12e18), 12e18);
        assertEq(wrapper.previewWithdraw(24e18), 24e18);
        assertEq(wrapper.previewWithdraw(64e18), 64e18);
        assertEq(wrapper.previewWithdraw(90e18), 90e18);
        assertEq(wrapper.previewWithdraw(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.withdraw(12e18, eoa1, eoa1);

        vm.prank(eoa2);
        wrapper.withdraw(24e18, eoa2, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 188e18);
        assertEq(wrapper.balanceOf(eoa2), 176e18);

        assertEq(wrapper.totalSupply(), 364e18);
        assertEq(wrapper.totalAssets(), 364e18);

        assertEq(wrapper.previewWithdraw(10e18), 10e18);
        assertEq(wrapper.previewWithdraw(12e18), 12e18);
        assertEq(wrapper.previewWithdraw(24e18), 24e18);
        assertEq(wrapper.previewWithdraw(64e18), 64e18);
        assertEq(wrapper.previewWithdraw(90e18), 90e18);
        assertEq(wrapper.previewWithdraw(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.withdraw(64e18, eoa2, eoa1);

        vm.prank(eoa2);
        wrapper.withdraw(10e18, eoa1, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 124e18);
        assertEq(wrapper.balanceOf(eoa2), 166e18);

        assertEq(wrapper.totalSupply(), 290e18);
        assertEq(wrapper.totalAssets(), 290e18);

        assertEq(wrapper.previewWithdraw(10e18), 10e18);
        assertEq(wrapper.previewWithdraw(12e18), 12e18);
        assertEq(wrapper.previewWithdraw(24e18), 24e18);
        assertEq(wrapper.previewWithdraw(64e18), 64e18);
        assertEq(wrapper.previewWithdraw(90e18), 90e18);
        assertEq(wrapper.previewWithdraw(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.withdraw(90e18, eoa1, eoa1);

        vm.prank(eoa2);
        wrapper.withdraw(100e18, eoa1, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 34e18);
        assertEq(wrapper.balanceOf(eoa2), 66e18);

        assertEq(wrapper.totalSupply(), 100e18);
        assertEq(wrapper.totalAssets(), 100e18);
    }

    function testRedeem() external {
        vm.prank(eoa1);
        wrapper.mint(100e18, eoa1);

        vm.prank(eoa2);
        wrapper.mint(100e18, eoa2);

        vm.prank(eoa1);
        wrapper.deposit(100e18, eoa2);

        vm.prank(eoa2);
        wrapper.deposit(100e18, eoa1);

        assertEq(wrapper.balanceOf(eoa1), 200e18);
        assertEq(wrapper.balanceOf(eoa2), 200e18);

        assertEq(wrapper.totalSupply(), 400e18);
        assertEq(wrapper.totalAssets(), 400e18);

        assertEq(wrapper.previewRedeem(10e18), 10e18);
        assertEq(wrapper.previewRedeem(12e18), 12e18);
        assertEq(wrapper.previewRedeem(24e18), 24e18);
        assertEq(wrapper.previewRedeem(64e18), 64e18);
        assertEq(wrapper.previewRedeem(90e18), 90e18);
        assertEq(wrapper.previewRedeem(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.redeem(12e18, eoa1, eoa1);

        vm.prank(eoa2);
        wrapper.redeem(24e18, eoa2, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 188e18);
        assertEq(wrapper.balanceOf(eoa2), 176e18);

        assertEq(wrapper.totalSupply(), 364e18);
        assertEq(wrapper.totalAssets(), 364e18);

        assertEq(wrapper.previewRedeem(10e18), 10e18);
        assertEq(wrapper.previewRedeem(12e18), 12e18);
        assertEq(wrapper.previewRedeem(24e18), 24e18);
        assertEq(wrapper.previewRedeem(64e18), 64e18);
        assertEq(wrapper.previewRedeem(90e18), 90e18);
        assertEq(wrapper.previewRedeem(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.redeem(64e18, eoa2, eoa1);

        vm.prank(eoa2);
        wrapper.redeem(10e18, eoa1, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 124e18);
        assertEq(wrapper.balanceOf(eoa2), 166e18);

        assertEq(wrapper.totalSupply(), 290e18);
        assertEq(wrapper.totalAssets(), 290e18);

        assertEq(wrapper.previewRedeem(10e18), 10e18);
        assertEq(wrapper.previewRedeem(12e18), 12e18);
        assertEq(wrapper.previewRedeem(24e18), 24e18);
        assertEq(wrapper.previewRedeem(64e18), 64e18);
        assertEq(wrapper.previewRedeem(90e18), 90e18);
        assertEq(wrapper.previewRedeem(100e18), 100e18);

        vm.prank(eoa1);
        wrapper.redeem(90e18, eoa1, eoa1);

        vm.prank(eoa2);
        wrapper.redeem(100e18, eoa1, eoa2);

        assertEq(wrapper.balanceOf(eoa1), 34e18);
        assertEq(wrapper.balanceOf(eoa2), 66e18);

        assertEq(wrapper.totalSupply(), 100e18);
        assertEq(wrapper.totalAssets(), 100e18);
    }
}
