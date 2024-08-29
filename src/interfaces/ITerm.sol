// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ITerm {
    function mint(address, uint256, uint256) external;

    function burn(address, uint256, uint256) external;

    function totalSupply(uint256) external view returns (uint256);
}
