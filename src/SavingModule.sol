// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {ISavingModule} from "src/interfaces/ISavingModule.sol";

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {compoundValue, dayCount} from "src/functions/TermCalculator.sol";

import {IToken} from "src/interfaces/IToken.sol";

contract SavingModule is AccessControl, ISavingModule {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("saving.module.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("saving.module.controller"));

    uint256 public lastTimestamp; // timestamp of the last update

    uint256 public currentRate = 0e12;
    uint256 public compoundFactorAccum = 1e8;

    uint256 public redeemFee = 0e6;

    IToken public immutable rusd;
    IToken public immutable srusd;

    constructor(address admin, IToken rusd_, IToken srusd_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        rusd = rusd_;
        srusd = srusd_;

        lastTimestamp = block.timestamp;
    }

    /// @notice Mint srUSD to one address and burn rUSD from the other
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Burned rUSD
    function mint(
        address from,
        address to,
        uint256 amount
    ) external onlyRole(CONTROLLER) {
        uint256 mintAmount = _mint(from, to, amount);

        emit Mint(from, to, mintAmount, amount, block.timestamp);
    }

    function _mint(
        address from,
        address to,
        uint256 amount
    ) private returns (uint256 mintAmount) {
        mintAmount = _previewMint(amount);

        assert(amount >= (mintAmount * _currentPrice()) / 1e8);

        rusd.burnFrom(from, amount);

        srusd.mint(to, mintAmount);
    }

    /// @notice Calculates the amount of srUSD that will be minted
    /// @param amount Burned rUSD
    /// @return uint256 Minted srUSD
    function previewMint(uint256 amount) external view returns (uint256) {
        return _previewMint(amount);
    }

    function _previewMint(uint256 amount) private view returns (uint256) {
        return (amount * 1e8) / _currentPrice();
    }

    /// @notice Burn srUSD from the sender address and mint rUSD to it
    /// @param amount Minted rUSD
    function redeem(uint256 amount) external {
        uint256 burnAmount = _redeem(msg.sender, msg.sender, amount);

        emit Redeem(
            msg.sender,
            msg.sender,
            amount,
            burnAmount,
            block.timestamp
        );
    }

    /// @notice Burn srUSD from the sender address and mint rUSD to the other
    /// @param to Receiver address
    /// @param amount Minted rUSD
    function redeem(address to, uint256 amount) external {
        uint256 burnAmount = _redeem(msg.sender, to, amount);

        emit Redeem(msg.sender, to, amount, burnAmount, block.timestamp);
    }

    function _redeem(
        address from,
        address to,
        uint256 amount
    ) private returns (uint256 burnAmount) {
        burnAmount = _previewRedeem(amount);

        assert((burnAmount * _currentPrice()) / 1e8 >= amount);

        srusd.burnFrom(from, (burnAmount * (1e6 + redeemFee)) / 1e6);

        rusd.mint(to, amount);
    }

    /// @notice Calculates the amount of srUSD that will be burned
    /// @param amount Minted rUSD
    /// @return uint256 Burned srUSD
    function previewRedeem(uint256 amount) external view returns (uint256) {
        return _previewRedeem(amount);
    }

    function _previewRedeem(uint256 amount) private view returns (uint256) {
        return Math.ceilDiv(amount * 1e8, _currentPrice());
    }

    /// @notice Total rUSD in circulation
    /// @return uint256 Total rUSD liability
    function rusdTotalLiability() external view returns (uint256) {
        return _rusdTotalLiability();
    }

    function _rusdTotalLiability() private view returns (uint256) {
        return
            rusd.totalSupply() + (srusd.totalSupply() * _currentPrice()) / 1e8;
    }

    /// @notice Total srUSD supply
    /// @return uint256 Total debt
    function totalDebt() external view returns (uint256) {
        return _totalDebt();
    }

    function _totalDebt() private view returns (uint256) {
        return srusd.totalSupply();
    }

    /// @notice Current price of srUSD in rUSD (always >= 1e8)
    /// @return uint256 Price
    function currentPrice() external view returns (uint256) {
        return _currentPrice();
    }

    function _currentPrice() private view returns (uint256) {
        return
            (compoundFactorAccum *
                _compoundFactor(1e8, block.timestamp, currentRate)) / 1e8;
    }

    /// @notice Compound factor calculation based on the initial time stamp
    /// @return uint256 Current compound factor
    function compoundFactor() external view returns (uint256) {
        return _compoundFactor(1e8, block.timestamp, currentRate);
    }

    function _compoundFactor(
        uint256 value,
        uint256 blockTimestamp,
        uint256 rate
    ) private view returns (uint256) {
        uint256 daysCount = dayCount(lastTimestamp, blockTimestamp);

        return compoundValue(value, daysCount, rate);
    }

    /// @notice Set the redemption fee for srUSD
    /// fee The percentage of the srUSD burned
    function setRedeemFee(uint256 fee) external onlyRole(MANAGER) {
        require(1e6 > fee, "SM: Fee can not be above 100%");

        redeemFee = fee;
    }

    /// @notice Set the interest for srUSD
    /// @param rate New value for the interest rate
    function update(uint256 rate) external onlyRole(MANAGER) {
        require(1e12 > rate, "SM: Savings rate can not be above 100% per anum");

        compoundFactorAccum =
            (compoundFactorAccum *
                _compoundFactor(1e8, block.timestamp, currentRate)) /
            1e8;

        emit Update(compoundFactorAccum, currentRate, rate, block.timestamp);

        currentRate = rate;
        lastTimestamp = block.timestamp;
    }
}
