// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Term} from "src/Term.sol";
import {LiquidTerm} from "src/LiquidTerm.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract LiquidTermTest is Test {
    Term term;

    LiquidTerm lTerm00;
    LiquidTerm lTerm01;
    LiquidTerm lTerm02;
    LiquidTerm lTerm03;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);
    address eoa3 = vm.addr(3);
    address eoa4 = vm.addr(4);

    function setUp() external {
        term = new Term(address(this), "https://reservoir.xyz");

        lTerm00 = new LiquidTerm("Liquid Term", "ltrUSD-00", address(term), 0);
        lTerm01 = new LiquidTerm("Liquid Term", "ltrUSD-01", address(term), 1);
        lTerm02 = new LiquidTerm("Liquid Term", "ltrUSD-02", address(term), 2);
        lTerm03 = new LiquidTerm("Liquid Term", "ltrUSD-03", address(term), 3);
    }

    function testInitialState() external {
        assertEq(lTerm00.tokenId(), 0);
        assertEq(lTerm00.registry(), address(term));

        assertEq(lTerm00.symbol(), "ltrUSD-00");
        assertEq(lTerm00.name(), "Liquid Term");

        assertEq(lTerm01.tokenId(), 1);
        assertEq(lTerm01.registry(), address(term));

        assertEq(lTerm02.symbol(), "ltrUSD-02");
        assertEq(lTerm02.name(), "Liquid Term");

        assertEq(lTerm02.tokenId(), 2);
        assertEq(lTerm02.registry(), address(term));

        assertEq(lTerm02.symbol(), "ltrUSD-02");
        assertEq(lTerm02.name(), "Liquid Term");

        assertEq(lTerm03.tokenId(), 3);
        assertEq(lTerm03.registry(), address(term));

        assertEq(lTerm03.symbol(), "ltrUSD-03");
        assertEq(lTerm03.name(), "Liquid Term");
    }

    function testBalanceAndTotalSupply() external {
        term.grantRole(term.MINTER(), address(this));

        term.mint(eoa1, 0, 1_000e18);
        term.mint(eoa2, 1, 1_000e18);
        term.mint(eoa3, 2, 1_000e18);
        term.mint(eoa4, 3, 1_000e18);

        assertEq(term.balanceOf(eoa1, 0), 1_000e18);
        assertEq(term.balanceOf(eoa2, 1), 1_000e18);
        assertEq(term.balanceOf(eoa3, 2), 1_000e18);
        assertEq(term.balanceOf(eoa4, 3), 1_000e18);

        assertEq(term.totalSupply(0), 1_000e18);
        assertEq(term.totalSupply(1), 1_000e18);
        assertEq(term.totalSupply(2), 1_000e18);
        assertEq(term.totalSupply(3), 1_000e18);

        assertEq(lTerm00.totalSupply(), 1_000e18);
        assertEq(lTerm01.totalSupply(), 1_000e18);
        assertEq(lTerm02.totalSupply(), 1_000e18);
        assertEq(lTerm03.totalSupply(), 1_000e18);

        assertEq(lTerm00.balanceOf(eoa1), 1_000e18);
        assertEq(lTerm00.balanceOf(eoa2), 0);
        assertEq(lTerm00.balanceOf(eoa3), 0);
        assertEq(lTerm00.balanceOf(eoa4), 0);

        assertEq(lTerm01.balanceOf(eoa1), 0);
        assertEq(lTerm01.balanceOf(eoa2), 1_000e18);
        assertEq(lTerm01.balanceOf(eoa3), 0);
        assertEq(lTerm01.balanceOf(eoa4), 0);

        assertEq(lTerm02.balanceOf(eoa1), 0);
        assertEq(lTerm02.balanceOf(eoa2), 0);
        assertEq(lTerm02.balanceOf(eoa3), 1_000e18);
        assertEq(lTerm02.balanceOf(eoa4), 0);

        assertEq(lTerm03.balanceOf(eoa1), 0);
        assertEq(lTerm03.balanceOf(eoa2), 0);
        assertEq(lTerm03.balanceOf(eoa3), 0);
        assertEq(lTerm03.balanceOf(eoa4), 1_000e18);
    }

    function testTransfer() external {
        address receiver = vm.addr(uint256(keccak256("receiver")));

        term.grantRole(term.MINTER(), address(this));

        term.mint(eoa1, 0, 1_000e18);
        term.mint(eoa2, 1, 1_000e18);
        term.mint(eoa3, 2, 1_000e18);
        term.mint(eoa4, 3, 1_000e18);

        // eoa1

        assertEq(lTerm00.balanceOf(receiver), 0);
        assertEq(lTerm00.balanceOf(eoa1), 1_000e18);

        vm.prank(eoa1);
        term.setApprovalForAll(address(lTerm00), true);

        vm.prank(eoa1);
        lTerm00.transfer(receiver, 1e18);

        assertEq(lTerm00.balanceOf(receiver), 1e18);
        assertEq(lTerm00.balanceOf(eoa1), 999e18);

        // eoa2

        assertEq(lTerm01.balanceOf(receiver), 0);
        assertEq(lTerm01.balanceOf(eoa2), 1_000e18);

        vm.prank(eoa2);
        term.setApprovalForAll(address(lTerm01), true);

        vm.prank(eoa2);
        lTerm01.transfer(receiver, 1e18);

        assertEq(lTerm01.balanceOf(receiver), 1e18);
        assertEq(lTerm01.balanceOf(eoa2), 999e18);

        // eoa3

        assertEq(lTerm02.balanceOf(receiver), 0);
        assertEq(lTerm02.balanceOf(eoa3), 1_000e18);

        vm.prank(eoa3);
        term.setApprovalForAll(address(lTerm02), true);

        vm.prank(eoa3);
        lTerm02.transfer(receiver, 1e18);

        assertEq(lTerm02.balanceOf(receiver), 1e18);
        assertEq(lTerm02.balanceOf(eoa3), 999e18);

        // eoa4

        assertEq(lTerm03.balanceOf(receiver), 0);
        assertEq(lTerm03.balanceOf(eoa4), 1_000e18);

        vm.prank(eoa4);
        term.setApprovalForAll(address(lTerm03), true);

        vm.prank(eoa4);
        lTerm03.transfer(receiver, 1e18);

        assertEq(lTerm03.balanceOf(receiver), 1e18);
        assertEq(lTerm03.balanceOf(eoa4), 999e18);
    }

    function testTransferFrom() external {
        address receiver = vm.addr(uint256(keccak256("receiver")));

        term.grantRole(term.MINTER(), address(this));

        term.mint(eoa1, 0, 1_000e18);
        term.mint(eoa2, 1, 1_000e18);
        term.mint(eoa3, 2, 1_000e18);
        term.mint(eoa4, 3, 1_000e18);

        // eoa1

        assertEq(lTerm00.balanceOf(receiver), 0);
        assertEq(lTerm00.balanceOf(eoa1), 1_000e18);

        vm.prank(eoa1);
        term.setApprovalForAll(address(lTerm00), true);

        vm.prank(eoa1);
        lTerm00.approve(address(this), 1e18);

        lTerm00.transferFrom(eoa1, receiver, 1e18);

        assertEq(lTerm00.balanceOf(receiver), 1e18);
        assertEq(lTerm00.balanceOf(eoa1), 999e18);

        assertEq(lTerm00.allowance(eoa1, receiver), 0);

        // eoa2

        assertEq(lTerm01.balanceOf(receiver), 0);
        assertEq(lTerm01.balanceOf(eoa2), 1_000e18);

        vm.prank(eoa2);
        term.setApprovalForAll(address(lTerm01), true);

        vm.prank(eoa2);
        lTerm01.approve(address(this), 1e18);

        lTerm01.transferFrom(eoa2, receiver, 1e18);

        assertEq(lTerm01.balanceOf(receiver), 1e18);
        assertEq(lTerm01.balanceOf(eoa2), 999e18);

        assertEq(lTerm01.allowance(eoa2, receiver), 0);

        // eoa3

        assertEq(lTerm02.balanceOf(receiver), 0);
        assertEq(lTerm02.balanceOf(eoa3), 1_000e18);

        vm.prank(eoa3);
        term.setApprovalForAll(address(lTerm02), true);

        vm.prank(eoa3);
        lTerm02.approve(address(this), 1e18);

        lTerm02.transferFrom(eoa3, receiver, 1e18);

        assertEq(lTerm02.balanceOf(receiver), 1e18);
        assertEq(lTerm02.balanceOf(eoa3), 999e18);

        assertEq(lTerm02.allowance(eoa3, receiver), 0);

        // eoa4

        assertEq(lTerm03.balanceOf(receiver), 0);
        assertEq(lTerm03.balanceOf(eoa4), 1_000e18);

        vm.prank(eoa4);
        term.setApprovalForAll(address(lTerm03), true);

        vm.prank(eoa4);
        lTerm03.approve(address(this), 1e18);

        lTerm03.transferFrom(eoa4, receiver, 1e18);

        assertEq(lTerm03.balanceOf(receiver), 1e18);
        assertEq(lTerm03.balanceOf(eoa4), 999e18);

        assertEq(lTerm03.allowance(eoa2, receiver), 0);
    }
}
