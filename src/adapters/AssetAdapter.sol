// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IFund} from "src/interfaces/IFund.sol";
import {IAssetAdapter} from "src/interfaces/IAssetAdapter.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

contract UnderlyingAssetPrice is IOracle {
    AggregatorV3Interface aggregator;

    constructor(address _aggregator) {
        aggregator = AggregatorV3Interface(_aggregator);
    }

    function latestAnswer() external view returns (int256) {
        int256 answer;
        uint256 updatedAt;

        (, answer, , updatedAt, ) = aggregator.latestRoundData();

        return (block.timestamp > 1.1 days + updatedAt) ? int256(1e8) : answer;
    }
}

contract AssetPrice is IOracle {
    IFund public immutable fund;

    constructor(address fundAddress) {
        fund = IFund(fundAddress);
    }

    function latestAnswer() external view returns (int256) {
        uint256 currentPrice = fund.currentPrice();

        return
            currentPrice > uint256(type(int256).max)
                ? type(int256).max
                : int256(currentPrice);
    }
}

contract AssetAdapter is AccessControl, IAssetAdapter {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("asset.adapter.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("asset.adapter.controller"));

    uint256 public immutable duration;

    IOracle public immutable underlyingPriceOracle;
    IOracle public immutable fundPriceOracle;

    uint256 public underlyingRiskWeight = 0e6; // 100% = 1000000
    uint256 public fundRiskWeight = 0e6; // 100% = 1000000

    IFund public immutable fund;
    IERC20 public immutable underlying;

    uint8 public immutable DECIMAL_FACTOR;

    constructor(
        address admin,
        address underlyingAddr,
        address fundAddr,
        address underlyingPriceOracleAddr,
        address fundPriceOracleAddr,
        uint256 _duration
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        duration = _duration;

        underlying = IERC20(underlyingAddr);
        DECIMAL_FACTOR = IERC20Metadata(address(underlying)).decimals();

        fund = IFund(fundAddr);

        underlyingPriceOracle = IOracle(underlyingPriceOracleAddr);
        fundPriceOracle = IOracle(fundPriceOracleAddr);
    }

    /// @notice Deposit underlying into the contract
    /// @param amount underlying amount
    function allocate(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);

        emit Allocate(msg.sender, amount, block.timestamp);
    }

    /// @notice Withdraw underlying from the contract
    /// @param amount underlying amount
    function withdraw(uint256 amount) external onlyRole(CONTROLLER) {
        underlying.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    function deposit(uint256 amount) external onlyRole(CONTROLLER) {
        underlying.approve(address(fund), amount);

        fund.deposit(amount);

        emit Deposit(msg.sender, amount, block.timestamp);
    }

    function redeem(uint256 amount) external onlyRole(CONTROLLER) {
        fund.approve(address(fund), amount);

        fund.redeem(amount);

        emit Redeem(msg.sender, amount, block.timestamp);
    }

    /// @notice Set risk weight of pool's junior token
    /// @param riskWeight value for the risk weight
    function setUnderlyingRiskWeight(
        uint256 riskWeight
    ) external onlyRole(MANAGER) {
        require(1e6 > riskWeight, "FA: Risk Weight can not be above 100%");

        underlyingRiskWeight = riskWeight;

        emit UnderlyingRiskWeightUpdate(riskWeight, block.timestamp);
    }

    /// @notice Set risk weight of pool's junior token
    /// @param riskWeight value for the risk weight
    function setFundRiskWeight(uint256 riskWeight) external onlyRole(MANAGER) {
        require(1e6 > riskWeight, "FA: Risk Weight can not be above 100%");

        fundRiskWeight = riskWeight;

        emit FundRiskWeightUpdate(riskWeight, block.timestamp);
    }

    /// @notice Total value held by this contract
    /// @return Asset value of the contract in USD
    function totalValue() external view returns (uint256) {
        uint256 total = 0;

        total += _underlyingTotalValue();
        total += _fundTotalValue();

        return total;
    }

    /// @notice Risk adjusted value held by this contract
    function totalRiskValue() external view returns (uint256) {
        uint256 total = 0;

        total += _underlyingTotalRiskValue();
        total += _fundTotalRiskValue();

        return total;
    }

    function underlyingTotalRiskValue() external view returns (uint256) {
        return _underlyingTotalRiskValue();
    }

    function _underlyingTotalRiskValue() private view returns (uint256) {
        uint256 assets;

        (, assets) = fund.userDeposits(address(this));

        return _underlyingRiskValue(assets + _underlyingBalance());
    }

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

    function underlyingTotalValue() external view returns (uint256) {
        return _underlyingTotalValue();
    }

    function _underlyingTotalValue() private view returns (uint256) {
        uint256 assets;

        (, assets) = fund.userDeposits(address(this));

        return _underlyingValue(assets + _underlyingBalance());
    }

    function underlyingValue(uint256 amount) external view returns (uint256) {
        return _underlyingValue(amount);
    }

    function _underlyingValue(uint256 amount) private view returns (uint256) {
        return
            (_underlyingPriceOracleLatestAnswer() *
                amount *
                (10 ** (18 - DECIMAL_FACTOR))) / 1e8;
    }

    function underlyingBalance() external view returns (uint256) {
        return _underlyingBalance();
    }

    function _underlyingBalance() private view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    function fundTotalRiskValue() external view returns (uint256) {
        return _fundTotalRiskValue();
    }

    function _fundTotalRiskValue() private view returns (uint256) {
        uint256 shares;

        (, shares) = fund.userRedemptions(address(this));

        return _fundRiskValue(shares + _fundBalance());
    }

    function fundRiskValue(uint256 amount) external view returns (uint256) {
        return _fundRiskValue(amount);
    }

    function _fundRiskValue(uint256 amount) private view returns (uint256) {
        return (fundRiskWeight * _fundValue(amount)) / 1e6;
    }

    function fundTotalValue() external view returns (uint256) {
        return _fundTotalValue();
    }

    function _fundTotalValue() private view returns (uint256) {
        uint256 shares;

        (, shares) = fund.userRedemptions(address(this));

        return _fundValue(shares + _fundBalance());
    }

    function fundValue(uint256 amount) external view returns (uint256) {
        return _fundValue(amount);
    }

    function _fundValue(uint256 amount) private view returns (uint256) {
        return (_fundPriceOracleLatestAnswer() * amount) / 1e8;
    }

    function fundBalance() external view returns (uint256) {
        return _fundBalance();
    }

    function _fundBalance() private view returns (uint256) {
        return fund.balanceOf(address(this));
    }

    function _underlyingPriceOracleLatestAnswer()
        private
        view
        returns (uint256)
    {
        int256 latestAnswer = underlyingPriceOracle.latestAnswer();

        return latestAnswer > 0 ? uint256(latestAnswer) : 0;
    }

    function _fundPriceOracleLatestAnswer() private view returns (uint256) {
        int256 latestAnswer = fundPriceOracle.latestAnswer();

        return latestAnswer > 0 ? uint256(latestAnswer) : 0;
    }
}
