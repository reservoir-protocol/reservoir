// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

import {ERC1155Mock} from "openzeppelin-contracts/contracts/mocks/ERC1155Mock.sol";

import {ITerm, Term} from "src/Term.sol";
import {Stablecoin} from "src/Stablecoin.sol";

import {TermIssuer} from "src/TermIssuer.sol";

import {IToken} from "src/interfaces/IToken.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TermIssuerTest is Test {
    event MintTerm(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 principle,
        uint256 cost,
        uint256 timestamp
    );

    event RedeemTerm(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 principle,
        uint256 timestamp
    );

    TermIssuer termIssuer;

    address eoa1 = vm.addr(1);
    address eoa2 = vm.addr(2);

    function testInitialState() external {
        Term term;
        Stablecoin rusd;

        (termIssuer, rusd, term) = _setUp(91.25 days, 0);

        assertTrue(termIssuer.hasRole(0x00, address(this)));
        assertTrue(termIssuer.hasRole(termIssuer.CONTROLLER(), address(this)));

        assertTrue(rusd.hasRole(rusd.MINTER(), address(termIssuer)));
        assertTrue(term.hasRole(term.MINTER(), address(termIssuer)));

        assertEq(termIssuer.TERM_WINDOW(), 4);

        assertEq(termIssuer.GENESIS(), 0);
        assertEq(termIssuer.DELTA(), 91.25 days);

        assertEq(address(termIssuer.rusd()), address(rusd));
        assertEq(address(termIssuer.term()), address(term));

        assertEq(termIssuer.totalDebt(), 0);
    }

    function testMaturityTimestamp() external {
        (termIssuer, , ) = _setUp(90 days, 0);

        assertEq(termIssuer.maturityTimestamp(0), 0); // Thu Jan 01 1970 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(2), 15552000); // Tue Jun 30 1970 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(4), 31104000); // Sun Dec 27 1970 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(6), 46656000); // Fri Jun 25 1971 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(8), 62208000); // Wed Dec 22 1971 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(10), 77760000); // Mon Jun 19 1972 00:00:00 GMT+0000

        assertEq(termIssuer.maturityTimestamp(114), 886464000); // Tue Feb 03 1998 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(116), 902016000); // Sun Aug 02 1998 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(118), 917568000); // Fri Jan 29 1999 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(120), 933120000); // Wed Jul 28 1999 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(122), 948672000); // Mon Jan 24 2000 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(124), 964224000); // Sat Jul 22 2000 00:00:00 GMT+0000

        (termIssuer, , ) = _setUp(92.5 days, 0);

        assertEq(termIssuer.maturityTimestamp(0), 0); // Thu Jan 01 1970 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(2), 15984000); // Sun Jul 05 1970 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(4), 31968000); // Wed Jan 06 1971 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(6), 47952000); // Sat Jul 10 1971 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(8), 63936000); // Tue Jan 11 1972 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(10), 79920000); // Fri Jul 14 1972 00:00:00 GMT+0000

        assertEq(termIssuer.maturityTimestamp(114), 911088000); // Sun Nov 15 1998 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(116), 927072000); // Wed May 19 1999 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(118), 943056000); // Sat Nov 20 1999 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(120), 959040000); // Tue May 23 2000 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(122), 975024000); // Fri Nov 24 2000 00:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(124), 991008000); // Mon May 28 2001 00:00:00 GMT+0000

        (termIssuer, , ) = _setUp(90 days, 1704085200);

        assertEq(termIssuer.maturityTimestamp(0), 1704085200); // Mon Jan 01 2024 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(2), 1719637200); // Sat Jun 29 2024 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(4), 1735189200); // Thu Dec 26 2024 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(6), 1750741200); // Tue Jun 24 2025 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(8), 1766293200); // Sun Dec 21 2025 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(10), 1781845200); // Fri Jun 19 2026 05:00:00 GMT+0000

        assertEq(termIssuer.maturityTimestamp(114), 2590549200); // Sat Feb 03 2052 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(116), 2606101200); // Thu Aug 01 2052 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(118), 2621653200); // Tue Jan 28 2053 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(120), 2637205200); // Sun Jul 27 2053 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(122), 2652757200); // Fri Jan 23 2054 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(124), 2668309200); // Wed Jul 22 2054 05:00:00 GMT+0000

        (termIssuer, , ) = _setUp(92.5 days, 1704085200);

        assertEq(termIssuer.maturityTimestamp(0), 1704085200); // Mon Jan 01 2024 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(2), 1720069200); // Thu Jul 04 2024 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(4), 1736053200); // Sun Jan 05 2025 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(6), 1752037200); // Wed Jul 09 2025 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(8), 1768021200); // Sat Jan 10 2026 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(10), 1784005200); // Tue Jul 14 2026 05:00:00 GMT+0000

        assertEq(termIssuer.maturityTimestamp(114), 2615173200); // Thu Nov 14 2052 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(116), 2631157200); // Sun May 18 2053 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(118), 2647141200); // Wed Nov 19 2053 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(120), 2663125200); // Sat May 23 2054 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(122), 2679109200); // Tue Nov 24 2054 05:00:00 GMT+0000
        assertEq(termIssuer.maturityTimestamp(124), 2695093200); // Fri May 28 2055 05:00:00 GMT+0000
    }

    function testDiscountRate() external {
        (termIssuer, , ) = _setUp(90 days, 0);

        assertEq(termIssuer.getDiscountRate(2), 0);
        assertEq(termIssuer.getDiscountRate(4), 0);
        assertEq(termIssuer.getDiscountRate(6), 0);

        assertEq(termIssuer.getDiscountRate(124), 0);
        assertEq(termIssuer.getDiscountRate(236), 0);
        assertEq(termIssuer.getDiscountRate(348), 0);

        termIssuer.setDiscountRate(2, 0.0000000001e12);
        termIssuer.setDiscountRate(4, 0.0000000001e12);
        termIssuer.setDiscountRate(6, 0.0000000001e12);

        termIssuer.setDiscountRate(124, 0.0000000001e12);
        termIssuer.setDiscountRate(236, 0.0000000001e12);
        termIssuer.setDiscountRate(348, 0.0000000001e12);

        assertEq(termIssuer.getDiscountRate(2), 0.0000000001e12);
        assertEq(termIssuer.getDiscountRate(4), 0.0000000001e12);
        assertEq(termIssuer.getDiscountRate(6), 0.0000000001e12);

        assertEq(termIssuer.getDiscountRate(124), 0.0000000001e12);
        assertEq(termIssuer.getDiscountRate(236), 0.0000000001e12);
        assertEq(termIssuer.getDiscountRate(348), 0.0000000001e12);
    }

    // function testDaysCalc() external {
    //     (termIssuer, , ) = _setUp(90 days, 0);

    //     assertEq(termIssuer.daysCalc(1 days, 0), 0);
    //     assertEq(termIssuer.daysCalc(8 days, 0), 0);
    //     assertEq(termIssuer.daysCalc(12 days, 0), 0);

    //     assertEq(termIssuer.daysCalc(2 days, 1 days), 0);
    //     assertEq(termIssuer.daysCalc(20 days, 10 days), 0);

    //     assertEq(termIssuer.daysCalc(0, 1 days), 1);
    //     assertEq(termIssuer.daysCalc(0, 8 days), 8);
    //     assertEq(termIssuer.daysCalc(0, 12 days), 12);

    //     assertEq(termIssuer.daysCalc(100 days, 101 days), 1);
    //     assertEq(termIssuer.daysCalc(200 days, 400 days), 200);
    //     assertEq(termIssuer.daysCalc(1242 days, 1367 days), 125);
    // }

    function testInvalidMint() external {
        string memory message;

        Stablecoin rusd;

        assertEq(block.timestamp, 1);

        (termIssuer, rusd, ) = _setUp(90 days, 0);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(90 days * 100 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 99, 1_000e18, message);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 100, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 106, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 112, 1_000e18, message);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 0);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(92.5 days * 100 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 99, 1_000e18, message);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 100, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 106, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 112, 1_000e18, message);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(90 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(90 days * 219 + 1);
        // vm.warp(1704085200 - 90 days + 1);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(90 days * 220 + 1);
        // vm.warp(1704085200 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(90 days * 320 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 99, 1_000e18, message);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 100, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 106, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 112, 1_000e18, message);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(92.5 days * 213 + 1);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(92.5 days * 214 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 0, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 6, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 12, 1_000e18, message);

        vm.warp(92.5 days * 314 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 99, 1_000e18, message);

        message = "TI: term passed availability";
        _checkInvalidTermMint(eoa1, eoa1, 100, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 106, 1_000e18, message);

        message = "TI: term is not yet available";
        _checkInvalidTermMint(eoa1, eoa1, 112, 1_000e18, message);
    }

    function testSuccessfulMint() external {
        IERC1155 term;
        Stablecoin rusd;

        assertEq(block.timestamp, 1);

        (termIssuer, rusd, ) = _setUp(90 days, 0);
        term = IERC1155(address(termIssuer.term()));

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);

        assertEq(termIssuer.totalDebt(), 1_000e18);
        assertEq(termIssuer.totalSupply(1), 1_000e18);

        assertEq(term.balanceOf(eoa1, 1), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);

        assertEq(termIssuer.totalDebt(), 2_000e18);
        assertEq(termIssuer.totalSupply(3), 1_000e18);

        assertEq(term.balanceOf(eoa1, 3), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        assertEq(termIssuer.totalDebt(), 3_000e18);
        assertEq(termIssuer.totalSupply(5), 1_000e18);

        assertEq(term.balanceOf(eoa2, 5), 1_000e18);

        vm.warp(90 days * 100 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);

        assertEq(termIssuer.totalDebt(), 4_000e18);
        assertEq(termIssuer.totalSupply(101), 1_000e18);

        assertEq(term.balanceOf(eoa1, 101), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);

        assertEq(termIssuer.totalDebt(), 5_000e18);
        assertEq(termIssuer.totalSupply(103), 1_000e18);

        assertEq(term.balanceOf(eoa1, 103), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        assertEq(termIssuer.totalDebt(), 6_000e18);
        assertEq(termIssuer.totalSupply(105), 1_000e18);

        assertEq(term.balanceOf(eoa2, 105), 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 0);
        term = IERC1155(address(termIssuer.term()));

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);

        assertEq(termIssuer.totalDebt(), 1_000e18);
        assertEq(termIssuer.totalSupply(1), 1_000e18);

        assertEq(term.balanceOf(eoa1, 1), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);

        assertEq(termIssuer.totalDebt(), 2_000e18);
        assertEq(termIssuer.totalSupply(3), 1_000e18);

        assertEq(term.balanceOf(eoa1, 3), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        assertEq(termIssuer.totalDebt(), 3_000e18);
        assertEq(termIssuer.totalSupply(5), 1_000e18);

        assertEq(term.balanceOf(eoa2, 5), 1_000e18);

        vm.warp(92.5 days * 100 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);

        assertEq(termIssuer.totalDebt(), 4_000e18);
        assertEq(termIssuer.totalSupply(101), 1_000e18);

        assertEq(term.balanceOf(eoa1, 101), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);

        assertEq(termIssuer.totalDebt(), 5_000e18);
        assertEq(termIssuer.totalSupply(103), 1_000e18);

        assertEq(term.balanceOf(eoa1, 103), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        assertEq(termIssuer.totalDebt(), 6_000e18);
        assertEq(termIssuer.totalSupply(105), 1_000e18);

        assertEq(term.balanceOf(eoa2, 105), 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(90 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        vm.warp(90 days * 220 + 1);
        // vm.warp(1704085200 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);

        assertEq(termIssuer.totalDebt(), 1_000e18);
        assertEq(termIssuer.totalSupply(1), 1_000e18);

        assertEq(term.balanceOf(eoa1, 1), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);

        assertEq(termIssuer.totalDebt(), 2_000e18);
        assertEq(termIssuer.totalSupply(3), 1_000e18);

        assertEq(term.balanceOf(eoa1, 3), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        assertEq(termIssuer.totalDebt(), 3_000e18);
        assertEq(termIssuer.totalSupply(5), 1_000e18);

        assertEq(term.balanceOf(eoa2, 5), 1_000e18);

        vm.warp(90 days * 320 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);

        assertEq(termIssuer.totalDebt(), 4_000e18);
        assertEq(termIssuer.totalSupply(101), 1_000e18);

        assertEq(term.balanceOf(eoa1, 101), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);

        assertEq(termIssuer.totalDebt(), 5_000e18);
        assertEq(termIssuer.totalSupply(103), 1_000e18);

        assertEq(term.balanceOf(eoa1, 103), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        assertEq(termIssuer.totalDebt(), 6_000e18);
        assertEq(termIssuer.totalSupply(105), 1_000e18);

        assertEq(term.balanceOf(eoa2, 105), 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        vm.warp(92.5 days * 214 + 1);
        // vm.warp(1704085200 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);

        assertEq(termIssuer.totalDebt(), 1_000e18);
        assertEq(termIssuer.totalSupply(1), 1_000e18);

        assertEq(term.balanceOf(eoa1, 1), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);

        assertEq(termIssuer.totalDebt(), 2_000e18);
        assertEq(termIssuer.totalSupply(3), 1_000e18);

        assertEq(term.balanceOf(eoa1, 3), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        assertEq(termIssuer.totalDebt(), 3_000e18);
        assertEq(termIssuer.totalSupply(5), 1_000e18);

        assertEq(term.balanceOf(eoa2, 5), 1_000e18);

        vm.warp(92.5 days * 314 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);

        assertEq(termIssuer.totalDebt(), 4_000e18);
        assertEq(termIssuer.totalSupply(101), 1_000e18);

        assertEq(term.balanceOf(eoa1, 101), 1_000e18);

        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);

        assertEq(termIssuer.totalDebt(), 5_000e18);
        assertEq(termIssuer.totalSupply(103), 1_000e18);

        assertEq(term.balanceOf(eoa1, 103), 1_000e18);

        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        assertEq(termIssuer.totalDebt(), 6_000e18);
        assertEq(termIssuer.totalSupply(105), 1_000e18);

        assertEq(term.balanceOf(eoa2, 105), 1_000e18);
    }

    function testInvalidRedeem() external {
        // uint256 cost;

        IERC1155 term;
        Stablecoin rusd;

        assertEq(block.timestamp, 1);

        (termIssuer, rusd, ) = _setUp(90 days, 0);
        term = IERC1155(address(termIssuer.term()));

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 1, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 3, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 5, 1_000e18);

        vm.warp(90 days * 100 + 1);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 101, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 103, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 105, 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 0);
        term = IERC1155(address(termIssuer.term()));

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 1, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 3, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 5, 1_000e18);

        vm.warp(92.5 days * 100 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 101, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 103, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 105, 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(90 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        vm.warp(90 days * 220 + 1);
        // vm.warp(1704085200 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 1, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 3, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 5, 1_000e18);

        vm.warp(90 days * 320 + 1);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 101, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 103, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 105, 1_000e18);

        vm.warp(1);

        (termIssuer, rusd, ) = _setUp(92.5 days, 1704085200);

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        assertEq(termIssuer.latestID(), 0);
        assertEq(termIssuer.earliestID(), 0);

        vm.warp(92.5 days * 214 + 1);
        // vm.warp(1704085200 + 1);

        assertEq(termIssuer.latestID(), 5);
        assertEq(termIssuer.earliestID(), 1);

        _checkValidTermMint(eoa1, eoa1, 1, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 3, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 5, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 1, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 3, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 5, 1_000e18);

        vm.warp(92.5 days * 314 + 1);

        assertEq(termIssuer.latestID(), 105);
        assertEq(termIssuer.earliestID(), 101);

        _checkValidTermMint(eoa1, eoa1, 101, 1_000e18);
        _checkValidTermMint(eoa2, eoa1, 103, 1_000e18);
        _checkValidTermMint(eoa1, eoa2, 105, 1_000e18);

        _checkInvalidTermRedeem(eoa1, eoa1, 101, 1_000e18);
        _checkInvalidTermRedeem(eoa2, eoa1, 103, 1_000e18);
        _checkInvalidTermRedeem(eoa1, eoa2, 105, 1_000e18);
    }

    function testSuccessfulRedeem() external {
        IERC1155 term;
        Stablecoin rusd;

        (termIssuer, rusd, ) = _setUp(91.25 days, 0);
        term = IERC1155(address(termIssuer.term()));

        uint256 rusdBalance1;
        uint256 rusdBalance2;

        deal(address(rusd), eoa1, 1_000_000e18, true);
        deal(address(rusd), eoa2, 1_000_000e18, true);

        vm.prank(eoa1);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa2);
        IERC20(address(rusd)).approve(address(termIssuer), type(uint256).max);

        vm.prank(eoa1);
        term.setApprovalForAll(address(termIssuer), true);

        vm.prank(eoa2);
        term.setApprovalForAll(address(termIssuer), true);

        vm.expectEmit(true, true, true, true);
        emit MintTerm(
            eoa1,
            eoa1,
            1,
            10_000e18,
            termIssuer.applyDiscount(
                10_000e18,
                termIssuer.maturityTimestamp(1),
                termIssuer.getDiscountRate(1)
            ),
            block.timestamp
        );
        termIssuer.mint(eoa1, eoa1, 1, 10_000e18);

        skip(91.25 days);

        rusdBalance1 = rusd.balanceOf(eoa1);
        rusdBalance2 = rusd.balanceOf(eoa2);

        assertEq(termIssuer.totalDebt(), 10_000e18);

        vm.expectEmit(true, true, true, true);
        emit RedeemTerm(eoa1, eoa1, 1, 5_000e18, block.timestamp);
        vm.prank(eoa1);
        termIssuer.redeem(1, 5_000e18);

        vm.expectEmit(true, true, true, true);
        emit RedeemTerm(eoa1, eoa2, 1, 5_000e18, block.timestamp);
        vm.prank(eoa1);
        termIssuer.redeem(eoa2, 1, 5_000e18);

        assertEq(termIssuer.totalDebt(), 0);
        assertEq(term.balanceOf(eoa1, 1), 0);

        assertEq(rusd.balanceOf(eoa1), rusdBalance1 + 5_000e18);
        assertEq(rusd.balanceOf(eoa2), rusdBalance2 + 5_000e18);

        vm.expectEmit(true, true, true, true);
        emit MintTerm(
            eoa2,
            eoa2,
            3,
            4_000e18,
            termIssuer.applyDiscount(
                4_000e18,
                termIssuer.maturityTimestamp(3),
                termIssuer.getDiscountRate(3)
            ),
            block.timestamp
        );
        termIssuer.mint(eoa2, eoa2, 3, 4_000e18);

        rusdBalance1 = rusd.balanceOf(eoa2);
        rusdBalance2 = rusd.balanceOf(eoa2);

        assertEq(termIssuer.totalDebt(), 4_000e18);

        skip(91.25 days);
        skip(91.25 days);

        vm.expectEmit(true, true, true, true);
        emit RedeemTerm(eoa2, eoa2, 3, 2_000e18, block.timestamp);
        vm.prank(eoa2);
        termIssuer.redeem(3, 2_000e18);

        vm.expectEmit(true, true, true, true);
        emit RedeemTerm(eoa2, eoa1, 3, 2_000e18, block.timestamp);
        vm.prank(eoa2);
        termIssuer.redeem(eoa1, 3, 2_000e18);

        assertEq(termIssuer.totalDebt(), 0);
        assertEq(term.balanceOf(eoa2, 3), 0);

        assertEq(rusd.balanceOf(eoa2), rusdBalance1 + 2_000e18);
        assertEq(rusd.balanceOf(eoa2), rusdBalance2 + 2_000e18);

        assertEq(termIssuer.totalSupply(0), 0);
        assertEq(termIssuer.totalSupply(1), 0);

        assertEq(termIssuer.totalSupply(2), 0);
        assertEq(termIssuer.totalSupply(3), 0);
    }

    function testApplyDiscount1() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(101.00e18, mt, 0.00006859294e12);

        assertApproxEqRel(pv, 100.3784e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(101.00e18, mt, 0.00008217862e12);

        assertApproxEqRel(pv, 100.5109e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00008217862e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(101.00e18, mt, 0.00009574398e12);

        assertApproxEqRel(pv, 100.4018e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00008217862e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(1.00e18, mt, 0.00009574398e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(101.00e18, mt, 0.00021578100e12);

        assertApproxEqRel(pv, 96.4056e18, 0.0001e18);
    }

    function testApplyDiscount2() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(101.50e18, mt, 0.00006859294e12);

        assertApproxEqRel(pv, 100.8754e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(101.50e18, mt, 0.00008221185e12);

        assertApproxEqRel(pv, 101.4999e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00008221185e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(101.50e18, mt, 0.00009583227e12);

        assertApproxEqRel(pv, 101.8763e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00006859294e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00008221185e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(1.50e18, mt, 0.00009583227e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(101.50e18, mt, 0.00021675436e12);

        assertApproxEqRel(pv, 98.3121e18, 0.0001e18);
    }

    function testApplyDiscount3() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(101.25e18, mt, 0.00010895236e12);

        assertApproxEqRel(pv, 100.2621e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00010895236e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(101.25e18, mt, 0.00012235981e12);

        assertApproxEqRel(pv, 100.2823e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00010895236e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00012235981e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(101.25e18, mt, 0.00014244981e12);

        assertApproxEqRel(pv, 99.8906e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00010895236e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00012235981e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(1.25e18, mt, 0.00014244981e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(101.25e18, mt, 0.00020227404e12);

        assertApproxEqRel(pv, 97.8033e18, 0.0001e18);
    }

    function testApplyDiscount4() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00007536025e12);

        assertApproxEqRel(pv, 99.8207e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00007536025e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00008887958e12);

        assertApproxEqRel(pv, 99.4017e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00007536025e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00008887958e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00010235664e12);

        assertApproxEqRel(pv, 98.7494e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00007536025e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00008887958e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00010235664e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00012918697e12);

        assertApproxEqRel(pv, 97.4084e18, 0.0001e18);
    }

    function testApplyDiscount5() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00026478555e12);

        assertApproxEqRel(pv, 98.1336e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00026478555e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00031497987e12);

        assertApproxEqRel(pv, 95.4496e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00026478555e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00031497987e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00036437905e12);

        assertApproxEqRel(pv, 92.0457e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00026478555e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00031497987e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(0.50e18, mt, 0.00036437905e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(100.50e18, mt, 0.00050802346e12);

        assertApproxEqRel(pv, 85.1203e18, 0.0001e18);
    }

    function testApplyDiscount6() external {
        uint256 pv;
        uint256 mt;

        (termIssuer, , ) = _setUp(90 days, 0);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(103.00e18, mt, 0.00004135811e12);

        assertApproxEqRel(pv, 102.6173e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00004135811e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(103.00e18, mt, 0.00005520872e12);

        assertApproxEqRel(pv, 104.9704e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00004135811e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00005520872e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(103.00e18, mt, 0.00008304110e12);

        assertApproxEqRel(pv, 106.6756e18, 0.0001e18);

        pv = 0;

        mt = termIssuer.maturityTimestamp(1) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00004135811e12);

        mt = termIssuer.maturityTimestamp(2) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00005520872e12);

        mt = termIssuer.maturityTimestamp(3) + block.timestamp;
        pv += termIssuer.applyDiscount(3.00e18, mt, 0.00008304110e12);

        mt = termIssuer.maturityTimestamp(4) + block.timestamp;
        pv += termIssuer.applyDiscount(103.00e18, mt, 0.00013863014e12);

        assertApproxEqRel(pv, 106.8788e18, 0.0001e18);
    }

    function testSetDiscountRate(uint64 rate, uint8 term) external {
        (termIssuer, , ) = _setUp(90 days, 0);

        if (rate >= 1e12) {
            vm.expectRevert("TI: Rate can not be above 100%");
            termIssuer.setDiscountRate(term, rate);
        } else {
            termIssuer.setDiscountRate(term, rate);
            assertEq(termIssuer.getDiscountRate(term), rate);
        }
    }

    function _checkValidTermMint(
        address to,
        address from,
        uint256 index,
        uint256 amount
    ) private {
        uint256 cost;

        bool valid;
        string memory message;

        (valid, message) = termIssuer.canMint(index);

        assertTrue(valid);
        assertEq(message, "");

        cost = termIssuer.mint(to, from, index, amount);

        console.log(" * cost %d", cost);
    }

    function _checkInvalidTermMint(
        address to,
        address from,
        uint256 index,
        uint256 amount,
        string memory refMessage
    ) private {
        uint256 cost;

        bool valid;
        string memory message;

        (valid, message) = termIssuer.canMint(index);

        assertFalse(valid);
        assertEq(message, refMessage);

        vm.expectRevert(bytes(refMessage));
        cost = termIssuer.mint(to, from, index, amount);

        console.log(" * cost %d", cost);
    }

    function _checkInvalidTermRedeem(
        address to,
        address from,
        uint256 index,
        uint256 amount
    ) private {
        uint256 cost;

        bool valid;
        string memory message;

        string memory refMessage = "TI: maturity has not passed";

        (valid, message) = termIssuer.canRedeem(index);

        console.log(valid);
        console.log(message);

        assertFalse(valid);
        assertEq(message, refMessage);

        vm.expectRevert(bytes(refMessage));

        vm.prank(from);
        termIssuer.redeem(index, amount);

        vm.expectRevert(bytes(refMessage));

        vm.prank(from);
        termIssuer.redeem(to, index, amount);

        console.log(" * cost %d", cost);
    }

    function _setUp(
        uint256 delta,
        uint256 genesis
    ) private returns (TermIssuer _termIssuer, Stablecoin rusd, Term term) {
        rusd = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");

        term = new Term(address(this), "https://reservoir.io/terms/");

        _termIssuer = new TermIssuer(
            address(this),
            delta,
            genesis,
            ITerm(address(term)),
            IToken(address(rusd))
        );

        rusd.grantRole(rusd.MINTER(), address(_termIssuer));
        term.grantRole(term.MINTER(), address(_termIssuer));

        _termIssuer.grantRole(_termIssuer.MANAGER(), address(this));
        _termIssuer.grantRole(_termIssuer.CONTROLLER(), address(this));
    }
}
