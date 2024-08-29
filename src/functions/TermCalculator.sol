// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

function compoundValue(
    uint256 value,
    uint256 daysCount,
    uint256 discountRate
) pure returns (uint256) {
    return (value * compoundFactor(daysCount, discountRate)) / 1e36;
}

function compoundFactor(
    uint256 daysCount,
    uint256 discountRate
) pure returns (uint256) {
    uint256 n = daysCount;
    uint256 r = discountRate;

    uint256 term1 = 1e36;
    uint256 term2 = 1e24 * n * r;

    if (n == 0) return term1 + term2;

    uint256 term3 = (1e12 * (n * (n - 1) * r ** 2)) / 2;

    if (n == 1) return term1 + term2 + term3;

    uint256 term4 = (n * (n - 1) * (n - 2) * r ** 3) / 6;

    return term1 + term2 + term3 + term4;
}

function discountValue(
    uint256 value,
    uint256 daysCount,
    uint256 discountRate
) pure returns (uint256) {
    return ((value * 1e36) / compoundFactor(daysCount, discountRate));
}

function dayCount(
    uint256 openTimestamp,
    uint256 closeTimestamp
) pure returns (uint256) {
    if (openTimestamp > closeTimestamp) return 0;

    return (closeTimestamp - openTimestamp) / 1 days;
}
