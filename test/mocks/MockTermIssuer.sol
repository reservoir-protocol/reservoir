// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ITerm} from "src/Term.sol";

import {IToken} from "src/interfaces/IToken.sol";

contract MockTermIssuer {
    ITerm public term;
    IToken public usdr;

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

    mapping(uint256 => uint256) public totalSupply;

    constructor(address term_, address usdr_) {
        term = ITerm(term_);
        usdr = IToken(usdr_);
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

    function setTotalSupply(uint256 id, uint256 amount) external {
        totalSupply[id] = amount;
    }
}
