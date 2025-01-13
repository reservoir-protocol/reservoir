// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Wrapper} from "src/Wrapper.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract WrapperTest is Test {
    Stablecoin usdr;

    Wrapper wrapper;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    // address eoa3 = vm.addr(3);
    // address eoa4 = vm.addr(4);

    function setUp() external {
        usdr = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        usdr.grantRole(usdr.MINTER(), address(this));

        wrapper = new Wrapper("Wrapped Reservoir Stablecoin", "wrUSD", usdr);

        usdr.mint(eoa1, 1_000e18);
        usdr.mint(eoa2, 1_000e18);

        vm.prank(eoa1);
        usdr.approve(address(wrapper), type(uint256).max);

        vm.prank(eoa2);
        usdr.approve(address(wrapper), type(uint256).max);
    }

    function testInitialState() external {
        assertEq(wrapper.symbol(), "wrUSD");
        assertEq(wrapper.name(), "Wrapped Reservoir Stablecoin");

        assertEq(wrapper.decimals(), 18);
        assertEq(wrapper.asset(), address(usdr));

        assertEq(wrapper.totalAssets(), 0);
        assertEq(wrapper.totalSupply(), 0);

        assertEq(usdr.balanceOf(eoa1), 1_000e18);
        assertEq(usdr.balanceOf(eoa2), 1_000e18);

        assertEq(usdr.totalSupply(), 2_000e18);
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
        usdr.mint(eoa1, 1_000e18);
        usdr.mint(eoa2, 1_000e18);

        vm.prank(eoa1);
        usdr.approve(address(wrapper), type(uint256).max);

        vm.prank(eoa2);
        usdr.approve(address(wrapper), type(uint256).max);

        assertEq(usdr.balanceOf(eoa1), 1_000e18);
        assertEq(usdr.balanceOf(eoa2), 1_000e18);

        assertEq(usdr.totalSupply(), 2_000e18);

        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");
        console.log(wrapper.totalSupply());
        console.log(wrapper.totalAssets());
        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");

        vm.prank(eoa1);
        wrapper.deposit(1_00e18, eoa1);

        console.log(wrapper.previewMint(100e18));
        console.log(wrapper.balanceOf(eoa1));

        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");
        console.log(wrapper.totalSupply());
        console.log(wrapper.totalAssets());
        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");

        vm.prank(eoa1);
        wrapper.deposit(1_00e18, eoa2);

        console.log(wrapper.previewMint(100e18));
        console.log(wrapper.balanceOf(eoa2));

        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");
        console.log(wrapper.totalSupply());
        console.log(wrapper.totalAssets());
        console.log(" + + + + + + + + + + + + + + + + + + + + + + + + + + + ");

        assertTrue(true);
    }

    // function testBalanceAndTotalSupply() external {
    //     // wrapper.grantRole(term.MINTER(), address(this));

    //     wrapper.mint(eoa1, 0, 1_000e18);
    //     wrapper.mint(eoa2, 1, 1_000e18);
    //     wrapper.mint(eoa3, 2, 1_000e18);
    //     wrapper.mint(eoa4, 3, 1_000e18);

    //     // assertEq(wrapper.balanceOf(eoa1, 0), 1_000e18);
    //     // assertEq(wrapper.balanceOf(eoa2, 1), 1_000e18);
    //     // assertEq(wrapper.balanceOf(eoa3, 2), 1_000e18);
    //     // assertEq(wrapper.balanceOf(eoa4, 3), 1_000e18);

    //     // assertEq(wrapper.totalSupply(0), 1_000e18);
    //     // assertEq(wrapper.totalSupply(1), 1_000e18);
    //     // assertEq(wrapper.totalSupply(2), 1_000e18);
    //     // assertEq(wrapper.totalSupply(3), 1_000e18);

    //     assertEq(wrapper.totalSupply(), 1_000e18);
    //     assertEq(wrapper.totalSupply(), 1_000e18);
    //     assertEq(wrapper.totalSupply(), 1_000e18);
    //     assertEq(wrapper.totalSupply(), 1_000e18);

    //     assertEq(wrapper.balanceOf(eoa1), 1_000e18);
    //     assertEq(wrapper.balanceOf(eoa2), 0);
    //     assertEq(wrapper.balanceOf(eoa3), 0);
    //     assertEq(wrapper.balanceOf(eoa4), 0);

    //     assertEq(wrapper.balanceOf(eoa1), 0);
    //     assertEq(wrapper.balanceOf(eoa2), 1_000e18);
    //     assertEq(wrapper.balanceOf(eoa3), 0);
    //     assertEq(wrapper.balanceOf(eoa4), 0);

    //     assertEq(wrapper.balanceOf(eoa1), 0);
    //     assertEq(wrapper.balanceOf(eoa2), 0);
    //     assertEq(wrapper.balanceOf(eoa3), 1_000e18);
    //     assertEq(wrapper.balanceOf(eoa4), 0);

    //     assertEq(wrapper.balanceOf(eoa1), 0);
    //     assertEq(wrapper.balanceOf(eoa2), 0);
    //     assertEq(wrapper.balanceOf(eoa3), 0);
    //     assertEq(wrapper.balanceOf(eoa4), 1_000e18);
    // }

    // function testTransfer() external {
    //     address receiver = vm.addr(uint256(keccak256("receiver")));

    //     wrapper.grantRole(term.MINTER(), address(this));

    //     wrapper.mint(eoa1, 0, 1_000e18);
    //     wrapper.mint(eoa2, 1, 1_000e18);
    //     wrapper.mint(eoa3, 2, 1_000e18);
    //     wrapper.mint(eoa4, 3, 1_000e18);

    //     // eoa1

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa1), 1_000e18);

    //     vm.prank(eoa1);
    //     wrapper.setApprovalForAll(address(lTerm00), true);

    //     vm.prank(eoa1);
    //     wrapper.transfer(receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa1), 999e18);

    //     // eoa2

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa2), 1_000e18);

    //     vm.prank(eoa2);
    //     wrapper.setApprovalForAll(address(lTerm01), true);

    //     vm.prank(eoa2);
    //     wrapper.transfer(receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa2), 999e18);

    //     // eoa3

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa3), 1_000e18);

    //     vm.prank(eoa3);
    //     wrapper.setApprovalForAll(address(lTerm02), true);

    //     vm.prank(eoa3);
    //     wrapper.transfer(receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa3), 999e18);

    //     // eoa4

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa4), 1_000e18);

    //     vm.prank(eoa4);
    //     wrapper.setApprovalForAll(address(lTerm03), true);

    //     vm.prank(eoa4);
    //     wrapper.transfer(receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa4), 999e18);
    // }

    // function testTransferFrom() external {
    //     address receiver = vm.addr(uint256(keccak256("receiver")));

    //     wrapper.grantRole(term.MINTER(), address(this));

    //     wrapper.mint(eoa1, 0, 1_000e18);
    //     wrapper.mint(eoa2, 1, 1_000e18);
    //     wrapper.mint(eoa3, 2, 1_000e18);
    //     wrapper.mint(eoa4, 3, 1_000e18);

    //     // eoa1

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa1), 1_000e18);

    //     vm.prank(eoa1);
    //     wrapper.setApprovalForAll(address(lTerm00), true);

    //     vm.prank(eoa1);
    //     wrapper.approve(address(this), 1e18);

    //     wrapper.transferFrom(eoa1, receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa1), 999e18);

    //     assertEq(wrapper.allowance(eoa1, receiver), 0);

    //     // eoa2

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa2), 1_000e18);

    //     vm.prank(eoa2);
    //     term.setApprovalForAll(address(lTerm01), true);

    //     vm.prank(eoa2);
    //     wrapper.approve(address(this), 1e18);

    //     wrapper.transferFrom(eoa2, receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa2), 999e18);

    //     assertEq(wrapper.allowance(eoa2, receiver), 0);

    //     // eoa3

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa3), 1_000e18);

    //     vm.prank(eoa3);
    //     wrapper.setApprovalForAll(address(lTerm02), true);

    //     vm.prank(eoa3);
    //     wrapper.approve(address(this), 1e18);

    //     wrapper.transferFrom(eoa3, receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa3), 999e18);

    //     assertEq(wrapper.allowance(eoa3, receiver), 0);

    //     // eoa4

    //     assertEq(wrapper.balanceOf(receiver), 0);
    //     assertEq(wrapper.balanceOf(eoa4), 1_000e18);

    //     vm.prank(eoa4);
    //     wrapper.setApprovalForAll(address(lTerm03), true);

    //     vm.prank(eoa4);
    //     wrapper.approve(address(this), 1e18);

    //     wrapper.transferFrom(eoa4, receiver, 1e18);

    //     assertEq(wrapper.balanceOf(receiver), 1e18);
    //     assertEq(wrapper.balanceOf(eoa4), 999e18);

    //     assertEq(wrapper.allowance(eoa2, receiver), 0);
    // }
}
