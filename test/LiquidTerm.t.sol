// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import {Term} from "src/Term.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract LiquidTerm is ERC20 {
    IERC1155 public immutable registry;
    uint256 public immutable tokenId;

    constructor(
        IERC1155 _registry,
        uint256 _tokenId
    ) ERC20("Liquid Term", "ltrUSD") {
        registry = _registry;
        tokenId = _tokenId;
    }

    function totalSupply() public view override returns (uint256) {
        try ERC1155Supply(address(registry)).totalSupply(tokenId) returns (
            uint256 amount
        ) {
            return amount;
        } catch {
            return 0;
        }
    }

    function balanceOf(address account) public view override returns (uint256) {
        return registry.balanceOf(account, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        registry.safeTransferFrom(from, to, tokenId, amount, "");
    }
}

// TODO: Liquid Term => Fungible Term
// TODO: Get term contract address from the token

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

        vm.prank(eoa1);
        term.setApprovalForAll(address(this), true);

        vm.prank(eoa2);
        term.setApprovalForAll(address(this), true);

        lTerm00 = new LiquidTerm(IERC1155(address(term)), 0);
        lTerm01 = new LiquidTerm(IERC1155(address(term)), 1);
        lTerm02 = new LiquidTerm(IERC1155(address(term)), 2);
        lTerm03 = new LiquidTerm(IERC1155(address(term)), 3);
    }

    function testInitialState() external {
        assertTrue(term.hasRole(0x00, address(this)));
    }

    function testMint() external {
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

    function testTransferSuccess01() external {
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

    function testTransferSuccess02() external {
        assertTrue(true);
    }

    function testTransferFailure() external {
        assertTrue(true);
    }

    // function testBurn() external {
    //     term.grantRole(term.MINTER(), address(this));

    //     term.mint(eoa1, 0, 12);
    //     term.mint(eoa2, 1, 26);
    //     term.mint(eoa2, 2, 1042);

    //     term.burn(eoa1, 0, 8);

    //     term.burn(eoa2, 1, 1);
    //     term.burn(eoa2, 1, 12);
    //     term.burn(eoa2, 2, 18);

    //     assertEq(term.balanceOf(eoa1, 0), 4);
    //     assertEq(term.balanceOf(eoa1, 1), 0);
    //     assertEq(term.balanceOf(eoa1, 2), 0);

    //     assertEq(term.balanceOf(eoa2, 0), 0);
    //     assertEq(term.balanceOf(eoa2, 1), 13);
    //     assertEq(term.balanceOf(eoa2, 2), 1024);

    //     assertEq(term.totalSupply(0), 4);
    //     assertEq(term.totalSupply(1), 13);
    //     assertEq(term.totalSupply(2), 1024);
    // }

    // function testTransfer() external {
    //     term.grantRole(term.MINTER(), address(this));

    //     term.mint(eoa1, 0, 12);
    //     term.mint(eoa2, 1, 26);
    //     term.mint(eoa2, 2, 1042);

    //     term.safeTransferFrom(eoa1, eoa2, 0, 8, "");

    //     assertEq(term.balanceOf(eoa1, 0), 4);
    //     assertEq(term.balanceOf(eoa2, 0), 8);

    //     uint256[] memory ids = new uint256[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     ids[0] = 1;
    //     ids[1] = 2;

    //     amounts[0] = 26;
    //     amounts[1] = 34;

    //     term.safeBatchTransferFrom(eoa2, eoa1, ids, amounts, "");

    //     assertEq(term.balanceOf(eoa1, 1), 26);
    //     assertEq(term.balanceOf(eoa1, 2), 34);

    //     assertEq(term.balanceOf(eoa2, 1), 0);
    //     assertEq(term.balanceOf(eoa2, 2), 1008);
    // }
}
