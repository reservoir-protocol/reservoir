// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {discountValue, dayCount} from "src/functions/TermCalculator.sol";

import {ITerm} from "src/Term.sol";
import {ITermIssuer} from "src/interfaces/ITermIssuer.sol";
import {IToken} from "src/interfaces/IToken.sol";

contract TermIssuer is AccessControl, ITermIssuer {
    uint256 public constant TERM_WINDOW = 4;

    bytes32 public constant MANAGER =
        keccak256(abi.encode("term.issuer.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("term.issuer.controller"));

    /// @notice Seconds between the term being available and the term maturing
    uint256 public immutable DELTA;

    /// @notice Starting timestamp for calculating term maturity dates
    uint256 public immutable GENESIS;

    ITerm public immutable term;
    IToken public immutable rusd;

    uint256 public totalDebt; // e18

    mapping(uint256 => uint256) public termDiscountRate; // e12

    constructor(
        address admin,
        uint256 delta,
        uint256 genesis,
        ITerm term_,
        IToken rusd_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        DELTA = delta;
        GENESIS = genesis;

        term = term_;
        rusd = rusd_;
    }

    /// @notice issues the term token #id to `to` address
    /// @param from address that will burn rUSD
    /// @param to address that will receive term tokens (trUSD)
    /// @param id identifier for the term
    /// @param amount balance for the term
    /// @return cost cost for the amount of the term
    function mint(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external onlyRole(CONTROLLER) returns (uint256 cost) {
        (bool valid, string memory message) = _canMint(id);
        require(valid, message);

        cost = _mint(from, to, id, amount);

        emit MintTerm(from, to, id, amount, cost, block.timestamp);
    }

    function _mint(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) private returns (uint256 cost) {
        uint256 mTimestamp = _maturityTimestamp(id);
        uint256 discountRate = _getDiscountRate(id);

        cost = _applyDiscount(amount, mTimestamp, discountRate);

        rusd.burnFrom(from, cost);
        term.mint(to, id, amount);

        totalDebt += amount;
    }

    /// @notice Verifies if the term is within the issue window
    /// @param id identifier for the term
    /// @return bool status for issuing the `id`
    /// @return string error message
    function canMint(uint256 id) external view returns (bool, string memory) {
        return _canMint(id);
    }

    function _canMint(uint256 id) private view returns (bool, string memory) {
        if (_earliestID(block.timestamp) > id)
            return (false, "TI: term passed availability");

        // prettier-ignore
        if (id > _latestID(block.timestamp) || _earliestID(block.timestamp) == 0) return (false, "TI: term is not yet available");

        return (true, "");
    }

    /// @notice redeems the given amount of specified term (trUSD)
    /// @param id identifier for the term
    /// @param amount balance of the term to redeem
    function redeem(uint256 id, uint256 amount) external {
        (bool valid, string memory message) = _canRedeem(id);
        require(valid, message);

        _redeem(msg.sender, msg.sender, id, amount);

        emit RedeemTerm(msg.sender, msg.sender, id, amount, block.timestamp);
    }

    /// @notice redeems the given amount of specified term (trUSD) to the receiving address
    /// @param to receiving address
    /// @param id identifier for the term
    /// @param amount balance of the term to redeem
    function redeem(address to, uint256 id, uint256 amount) external {
        (bool valid, string memory message) = _canRedeem(id);
        require(valid, message);

        _redeem(msg.sender, to, id, amount);

        emit RedeemTerm(msg.sender, to, id, amount, block.timestamp);
    }

    function _redeem(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) private {
        term.burn(from, id, amount);
        rusd.mint(to, amount);

        totalDebt -= amount;
    }

    /// @notice Checks if the term has matured and can be redeemed
    /// @param id identifier for the term
    /// @return bool status for redeeming the `id`
    /// @return string error message
    function canRedeem(uint256 id) external view returns (bool, string memory) {
        return _canRedeem(id);
    }

    function _canRedeem(uint256 id) private view returns (bool, string memory) {
        if (_maturityTimestamp(id) > block.timestamp) {
            return (false, "TI: maturity has not passed");
        }

        return (true, "");
    }

    /// @notice Discounted value calculation based on the maturity date
    /// @param value amount of term being discounted
    /// @param maturityTimestamp_ timestamp of maturity
    /// @param discountRate_ discount rate of the term
    /// @return uint256 the cost for the value
    function applyDiscount(
        uint256 value,
        uint256 maturityTimestamp_,
        uint256 discountRate_
    ) external view returns (uint256) {
        return _applyDiscount(value, maturityTimestamp_, discountRate_);
    }

    function _applyDiscount(
        uint256 value,
        uint256 maturityTimestamp_,
        uint256 discountRate_
    ) private view returns (uint256) {
        uint256 daysCount = dayCount(block.timestamp, maturityTimestamp_);

        return discountValue(value, daysCount, discountRate_);
    }

    /// @notice Returns the discount rate of the term
    /// @param id identifier for the term
    /// @return uint256 discount rate for the `id`
    function getDiscountRate(uint256 id) external view returns (uint256) {
        return _getDiscountRate(id);
    }

    function _getDiscountRate(uint256 id) private view returns (uint256) {
        return termDiscountRate[id];
    }

    /// @notice Sets the discount rate for the term
    /// @param id identifier for the term
    /// @param rate term's discount rate
    function setDiscountRate(
        uint256 id,
        uint256 rate
    ) external onlyRole(MANAGER) {
        require(1e12 > rate, "TI: Rate can not be above 100%");

        _setDiscountRate(id, rate);
    }

    function _setDiscountRate(uint256 id, uint256 rate) private {
        termDiscountRate[id] = rate;
    }

    /// @notice Calculates latest available `id`
    /// @return uint256 latest term ID
    function latestID() external view returns (uint256) {
        return _latestID(block.timestamp);
    }

    function _latestID(uint256 blockTimestamp) private view returns (uint256) {
        if (blockTimestamp > GENESIS)
            return 1 + TERM_WINDOW + (blockTimestamp - GENESIS) / DELTA;

        return 0;
    }

    /// @notice Calculates earliest available `id`
    /// @return uint256 earliest term ID
    function earliestID() external view returns (uint256) {
        return _earliestID(block.timestamp);
    }

    function _earliestID(
        uint256 blockTimestamp
    ) private view returns (uint256) {
        if (blockTimestamp > GENESIS)
            return 1 + (blockTimestamp - GENESIS) / DELTA;

        return 0;
    }

    /// @notice Maturity timestamp of the specified term
    /// @param id identifier for the term
    /// @return uint256 maturity timestamp of the term
    function maturityTimestamp(uint256 id) external view returns (uint256) {
        return _maturityTimestamp(id);
    }

    function _maturityTimestamp(uint256 id) private view returns (uint256) {
        return GENESIS + id * DELTA;
    }

    /// @notice Total number of the specified term tokens outstanding of a maturity
    /// @param id identifier for the term
    /// @return uint256 term's total supply
    function totalSupply(uint256 id) external view returns (uint256) {
        return _totalSupply(id);
    }

    function _totalSupply(uint256 id) private view returns (uint256) {
        return term.totalSupply(id);
    }
}
