// SPDX-License-Identifier: MIT

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.24;

interface IFund is IERC20 {
    function deposit(uint256) external;

    function redeem(uint256) external;

    function userDeposits(address) external view returns (uint256, uint256);

    function userRedemptions(address) external view returns (uint256, uint256);

    function currentPrice() external view returns (uint256);
}
