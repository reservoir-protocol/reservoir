// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {DAM} from "src/governance/DAM.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract DamTest is Test {
    DAM dam;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function setUp() external {
        dam = new DAM(address(this), "DAM", "Reservoir Protocol Token");
    }

    function testInitialState() external {
        assertTrue(dam.hasRole(0x00, address(this)));
    }

    function testMint() external {
        dam.grantRole(dam.MINTER(), address(this));

        dam.mint(eoa1, 100e18);
        dam.mint(eoa2, 100e18);

        assertEq(dam.balanceOf(eoa1), 100e18);
        assertEq(dam.balanceOf(eoa2), 100e18);

        // mint same term again
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
