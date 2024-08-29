// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IOracle {
    function latestAnswer() external view returns (int256);
}
