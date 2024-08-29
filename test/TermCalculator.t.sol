// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {compoundValue, discountValue, dayCount} from "src/functions/TermCalculator.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TermCalculatorTest is Test {
    function setUp() external {}

    function testAPR0() external {
        uint256 compound;
        uint256 discount;

        // compound

        compound = compoundValue(1e18, 0, 0);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 0, 0);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 0, 0);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 0, 0);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 0, 0);
        assertEq(compound, 1e18);

        // discount

        discount = discountValue(1e18, 0, 0);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 91, 0);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 182, 0);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 273, 0);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 365, 0);
        assertEq(discount, 1e18);
    }

    function testAPR1() external {
        uint256 compound;
        uint256 discount;

        // compound

        compound = compoundValue(1e18, 0, 0.000027261552e12);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 91, 0.000027261552e12);
        assertApproxEqRel(compound, 1.0025e18, 0.0001e18);

        compound = compoundValue(1e18, 182, 0.000027261552e12);
        assertApproxEqRel(compound, 1.0050e18, 0.0001e18);

        compound = compoundValue(1e18, 273, 0.000027261552e12);
        assertApproxEqRel(compound, 1.0075e18, 0.0001e18);

        compound = compoundValue(1e18, 365, 0.000027261552e12);
        assertApproxEqRel(compound, 1.0100e18, 0.0001e18);

        // discount

        discount = discountValue(1e18, 0, 0.000027261552e12);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 91, 0.000027261552e12);
        assertApproxEqRel(discount, 0.9975e18, 0.0001e18);

        discount = discountValue(1e18, 182, 0.000027261552e12);
        assertApproxEqRel(discount, 0.9951e18, 0.0001e18);

        discount = discountValue(1e18, 273, 0.000027261552e12);
        assertApproxEqRel(discount, 0.9926e18, 0.0001e18);

        discount = discountValue(1e18, 365, 0.000027261552e12);
        assertApproxEqRel(discount, 0.9901e18, 0.0001e18);
    }

    function testAPR8() external {
        uint256 compound;
        uint256 discount;

        // compound

        compound = compoundValue(1e18, 0, 0.000210874398e12);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 91, 0.000210874398e12);
        assertApproxEqRel(compound, 1.0194e18, 0.0001e18);

        compound = compoundValue(1e18, 182, 0.000210874398e12);
        assertApproxEqRel(compound, 1.0391e18, 0.0001e18);

        compound = compoundValue(1e18, 273, 0.000210874398e12);
        assertApproxEqRel(compound, 1.0593e18, 0.0001e18);

        compound = compoundValue(1e18, 365, 0.000210874398e12);
        assertApproxEqRel(compound, 1.0800e18, 0.0001e18);

        // discount

        discount = discountValue(1e18, 0, 0.000210874398e12);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 91, 0.000210874398e12);
        assertApproxEqRel(discount, 0.9810e18, 0.0001e18);

        discount = discountValue(1e18, 182, 0.000210874398e12);
        assertApproxEqRel(discount, 0.9624e18, 0.0001e18);

        discount = discountValue(1e18, 273, 0.000210874398e12);
        assertApproxEqRel(discount, 0.9441e18, 0.0001e18);

        discount = discountValue(1e18, 365, 0.000210874398e12);
        assertApproxEqRel(discount, 0.9259e18, 0.0001e18);
    }

    function testAPR15() external {
        uint256 compound;
        uint256 discount;

        // compound

        compound = compoundValue(1e18, 0, 0.00038298275e12);
        assertEq(compound, 1e18);

        compound = compoundValue(1e18, 91, 0.00038298275e12);
        assertApproxEqRel(compound, 1.0355e18, 0.0001e18);

        compound = compoundValue(1e18, 182, 0.00038298275e12);
        assertApproxEqRel(compound, 1.0722e18, 0.0001e18);

        compound = compoundValue(1e18, 273, 0.00038298275e12);
        assertApproxEqRel(compound, 1.1102e18, 0.0001e18);

        compound = compoundValue(1e18, 365, 0.00038298275e12);
        assertApproxEqRel(compound, 1.1500e18, 0.0001e18);

        // discount

        discount = discountValue(1e18, 0, 0.00038298275e12);
        assertEq(discount, 1e18);

        discount = discountValue(1e18, 91, 0.00038298275e12);
        assertApproxEqRel(discount, 0.9658e18, 0.0001e18);

        discount = discountValue(1e18, 182, 0.00038298275e12);
        assertApproxEqRel(discount, 0.9327e18, 0.0001e18);

        discount = discountValue(1e18, 273, 0.00038298275e12);
        assertApproxEqRel(discount, 0.9007e18, 0.0001e18);

        discount = discountValue(1e18, 365, 0.00038298275e12);
        assertApproxEqRel(discount, 0.869565e18, 0.0001e18);
    }
}
