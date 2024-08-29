// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

contract MockFund is ERC20DecimalsMock {
    struct Order {
        uint256 epoch;
        uint256 amount;
    }

    event Deposit(address, uint256);

    event Redemption(address, uint256);

    uint256 public totalDeposits;
    uint256 public totalRedemptions;

    uint256 public currentPrice;

    uint256 public totalValue;
    uint256 public totalRiskValue;

    mapping(address => Order) public userDeposits;
    mapping(address => Order) public userRedemptions;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20DecimalsMock(name_, symbol_, decimals_) {}

    function deposit(uint256 amount) external {
        userDeposits[msg.sender].amount += amount;

        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    function redeem(uint256 amount) external {
        userRedemptions[msg.sender].amount += amount;

        totalRedemptions += amount;

        emit Redemption(msg.sender, amount);
    }

    function updatePrice(uint256 price) external {
        currentPrice = price;
    }

    function setTotalValue(uint256 value) external {
        totalValue = value;
    }

    function setTotalRiskValue(uint256 value) external {
        totalRiskValue = value;
    }
}
