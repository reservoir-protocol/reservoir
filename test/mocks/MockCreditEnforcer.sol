// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ITermIssuer} from "src/TermIssuer.sol";

contract MockCreditEnforcer {
    ITermIssuer public termIssuer;

    struct Order {
        uint256 epoch;
        uint256 amount;
    }

    event Deposit(address, uint256);

    event Redemption(address, uint256);

    uint256 public totalDeposits;
    uint256 public totalRedemptions;

    uint256 public currentPrice;

    mapping(address => Order) public userDeposits;
    mapping(address => Order) public userRedemptions;

    constructor(address termIssuer_) {
        termIssuer = ITermIssuer(termIssuer_);
    }

    // function deposit(uint256 amount) external {
    //     userDeposits[msg.sender].amount += amount;

    //     totalDeposits += amount;

    //     emit Deposit(msg.sender, amount);
    // }

    // function redeem(uint256 amount) external {
    //     userRedemptions[msg.sender].amount += amount;

    //     totalRedemptions += amount;

    //     emit Redemption(msg.sender, amount);
    // }

    // function updatePrice(uint256 price) external {
    //     currentPrice = price;
    // }
}
