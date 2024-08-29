// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IPegStabilityModule} from "src/interfaces/IPegStabilityModule.sol";

import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IToken} from "src/interfaces/IToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

contract PegStabilityModule is AccessControl, Pausable, IPegStabilityModule {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("peg.stability.module.manager"));

    bytes32 public constant SUPERVISOR =
        keccak256(abi.encode("peg.stability.module.supervisor"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("peg.stability.module.controller"));

    IERC20 public immutable underlying;
    IToken public immutable rusd;

    IOracle public immutable underlyingPriceOracle;

    uint256 public underlyingRiskWeight; // e6

    uint8 public immutable DECIMAL_FACTOR;

    constructor(
        address admin,
        address underlyingPriceOracleAddr,
        IToken rusd_,
        IERC20 _underlying
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        underlyingPriceOracle = IOracle(underlyingPriceOracleAddr);

        underlying = _underlying;
        DECIMAL_FACTOR = IERC20Metadata(address(underlying)).decimals();

        rusd = rusd_;
    }

    /// @notice Transfer underlying to the contract from caller
    /// @param amount Underlying amount
    function allocate(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);

        emit Allocate(msg.sender, amount, block.timestamp);
    }

    /// @notice Withdraw underlying asset to caller
    /// @param amount Underlying amount
    function withdraw(uint256 amount) external onlyRole(CONTROLLER) {
        underlying.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    /// @notice Issue the stablecoin and transfer the underlying to the contract
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Underlying amount
    function mint(
        address from,
        address to,
        uint256 amount
    ) external onlyRole(CONTROLLER) {
        _mint(from, to, amount);

        emit Mint(from, to, amount, block.timestamp);
    }

    function _mint(address from, address to, uint256 transferAmount) private {
        uint256 balance = underlying.balanceOf(address(this));

        underlying.transferFrom(from, address(this), transferAmount);

        uint256 amount = underlying.balanceOf(address(this)) - balance;

        rusd.mint(to, amount * (10 ** (18 - DECIMAL_FACTOR)));
    }

    /// @notice Redeem the underlying to the sender for stablecoin
    /// @param amount Underlying amount
    function redeem(uint256 amount) external whenNotPaused {
        _redeem(msg.sender, msg.sender, amount);

        emit Redeem(msg.sender, msg.sender, amount, block.timestamp);
    }

    /// @notice Redeem the underlying to a recipient for stablecoin
    /// @param to Receiver address
    /// @param amount Underlying amount
    function redeem(address to, uint256 amount) external whenNotPaused {
        _redeem(msg.sender, to, amount);

        emit Redeem(msg.sender, to, amount, block.timestamp);
    }

    function _redeem(address from, address to, uint256 transferAmount) private {
        rusd.burnFrom(from, transferAmount * (10 ** (18 - DECIMAL_FACTOR)));

        underlying.transfer(to, transferAmount);
    }

    /// @notice Set risk weight for underlying asset
    /// @param riskWeight value of the risk weight
    function setUnderlyingRiskWeight(
        uint256 riskWeight
    ) external onlyRole(MANAGER) {
        require(1e6 > riskWeight, "PSM: Risk Weight can not be above 100%");

        underlyingRiskWeight = riskWeight;

        emit UnderlyingRiskWeightUpdate(riskWeight, block.timestamp);
    }

    /// @notice Total value held by this contract
    /// @return Asset value of the contract
    function totalValue() external view returns (uint256) {
        return _underlyingTotalValue();
    }

    /// @notice Risk adjusted value held by this contract
    /// @return amount value of the contracts risk value
    function totalRiskValue() external view returns (uint256) {
        return _underlyingTotalRiskValue();
    }

    /// @notice Risk adjusted value of underlying stablecoin held by this contract
    /// @return amount value of the contracts underlying stablecoins risk value
    function underlyingTotalRiskValue() external view returns (uint256) {
        return _underlyingTotalRiskValue();
    }

    function _underlyingTotalRiskValue() private view returns (uint256) {
        return _underlyingRiskValue(_underlyingBalance());
    }

    /// @notice Return risk value of specified amount of underlying stablecoin
    /// @param amount value of underlying stablecoin that the risk weight will be calculated against
    /// @return amount risk value of specified amount of underlying stablecoin
    function underlyingRiskValue(
        uint256 amount
    ) external view returns (uint256) {
        return _underlyingRiskValue(amount);
    }

    function _underlyingRiskValue(
        uint256 amount
    ) private view returns (uint256) {
        return (underlyingRiskWeight * _underlyingValue(amount)) / 1e6;
    }

    /// @notice Value of underlying stablecoin held by this contract
    /// @return amount value of the contracts underlying stablecoin
    function underlyingTotalValue() external view returns (uint256) {
        return _underlyingTotalValue();
    }

    function _underlyingTotalValue() private view returns (uint256) {
        return _underlyingValue(_underlyingBalance());
    }

    /// @notice Return value of specified underlying stablecoin
    /// @param amount value of underlying stablecoin
    /// @return amount value of specified underlying stablecoin
    function underlyingValue(uint256 amount) external view returns (uint256) {
        return _underlyingValue(amount);
    }

    function _underlyingValue(uint256 amount) private view returns (uint256) {
        return (_underlyingPriceOracleLatestAnswer() * amount * 1e12) / 1e8;
    }

    /// @notice Value of underlying stablecoin held by the contract
    /// @return amount Value of underlying stablecoin held by the contract
    function underlyingBalance() external view returns (uint256) {
        return _underlyingBalance();
    }

    function _underlyingBalance() private view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function _underlyingPriceOracleLatestAnswer()
        private
        view
        returns (uint256)
    {
        int256 latestAnswer = underlyingPriceOracle.latestAnswer();

        return latestAnswer > 0 ? uint256(latestAnswer) : 0;
    }

    /// @notice Stops redemption (for emergencies)
    function pause() external onlyRole(SUPERVISOR) {
        _pause();
    }

    /// @notice Resumes redemptions
    function unpause() external onlyRole(SUPERVISOR) {
        _unpause();
    }
}
