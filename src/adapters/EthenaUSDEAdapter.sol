// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {IOracle} from "src/interfaces/IOracle.sol";

import {IAssetAdapter} from "src/interfaces/IAssetAdapter.sol";

interface ICurveStableSwap {
    function price_oracle(uint256) external view returns (uint256);
}

contract EthenaSUSDEAdapter is IAssetAdapter, AccessControl {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("asset.adapter.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("asset.adapter.controller"));

    IERC4626 public immutable fund;
    IERC20 public immutable underlying;

    address public immutable holder;

    uint256 public immutable duration;

    IOracle public immutable fundPriceOracle;
    IOracle public immutable underlyingPriceOracle;

    uint256 public fundRiskWeight; // 100% = 1e6
    uint256 public underlyingRiskWeight; // 100% = 1e6

    ICurveStableSwap curveStableSwap =
        ICurveStableSwap(0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72);

    constructor(
        address _admin,
        address _holder,
        address _fundAddr,
        address _underlyingAddr,
        uint256 _duration
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        fund = IERC4626(_fundAddr);
        underlying = IERC20(_underlyingAddr);

        holder = _holder;

        duration = _duration;
    }

    function allocate(uint256 _assets) external {
        underlying.transferFrom(msg.sender, address(this), _assets);

        emit Allocate(msg.sender, _assets, block.timestamp);
    }

    function withdraw(uint256 _assets) external {
        underlying.transfer(msg.sender, _assets);

        emit Withdraw(msg.sender, _assets, block.timestamp);
    }

    function deposit(uint256 amount) public onlyRole(CONTROLLER) {
        // TODO: Replace with swap and deposit

        underlying.transfer(holder, amount);

        emit Deposit(msg.sender, amount, block.timestamp);
    }

    function redeem(uint256) public onlyRole(CONTROLLER) {
        // TODO: Replace with redeem and swap
    }

    function setUnderlyingRiskWeight(
        uint256 _riskWeight
    ) external onlyRole(MANAGER) {
        require(1e6 > _riskWeight, "FA: Risk Weight can not be above 100%");

        underlyingRiskWeight = _riskWeight;

        emit UnderlyingRiskWeightUpdate(_riskWeight, block.timestamp);
    }

    function setFundRiskWeight(uint256 _riskWeight) external onlyRole(MANAGER) {
        require(1e6 > _riskWeight, "FA: Risk Weight can not be above 100%");

        fundRiskWeight = _riskWeight;

        emit FundRiskWeightUpdate(_riskWeight, block.timestamp);
    }

    function totalValue() external view returns (uint256 total) {
        total += _fundTotalValue();
        total += _underlyingTotalValue();
    }

    function totalRiskValue() external view returns (uint256 total) {
        total += _fundTotalRiskValue();
        total += _underlyingTotalRiskValue();
    }

    function underlyingTotalRiskValue() external view returns (uint256) {
        return _underlyingTotalRiskValue();
    }

    function _underlyingTotalRiskValue() private view returns (uint256) {
        return _underlyingRiskValue(0);
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

    function underlyingTotalValue() external pure returns (uint256) {
        return _underlyingTotalValue();
    }

    function _underlyingTotalValue() private pure returns (uint256) {
        return _underlyingValue(0);
    }

    function underlyingValue(uint256 amount) external pure returns (uint256) {
        return _underlyingValue(amount);
    }

    function _underlyingValue(uint256 amount) private pure returns (uint256) {
        return (_underlyingPriceOracleLatestAnswer() * amount * 1e12) / 1e8;
    }

    function underlyingBalance() external pure returns (uint256) {
        return _underlyingBalance();
    }

    function _underlyingBalance() private pure returns (uint256) {
        return 0;
    }

    function fundTotalRiskValue() external view returns (uint256) {
        return _fundTotalRiskValue();
    }

    function _fundTotalRiskValue() private view returns (uint256) {
        return _fundRiskValue(_fundBalance());
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
        return _fundValue((_fundBalance()));
    }

    function fundValue(uint256 amount) external view returns (uint256) {
        return _fundValue(amount);
    }

    function _fundValue(uint256 amount) private view returns (uint256) {
        return (_fundPriceOracleLatestAnswer() * amount) / 1e18;
        // return 1e18 * fund.previewRedeem(amount) / curveStableSwap.price_oracle(0); // wrong underlying
    }

    function fundBalance() external view returns (uint256) {
        return _fundBalance();
    }

    function _fundBalance() private view returns (uint256) {
        return fund.balanceOf(holder);
    }

    function _underlyingPriceOracleLatestAnswer()
        private
        pure
        returns (uint256)
    {
        return 1e8;
    }

    function _fundPriceOracleLatestAnswer() private view returns (uint256) {
        return
            (1e18 * fund.previewRedeem(1e18)) / curveStableSwap.price_oracle(0);
    }

    function recover(address _token) external onlyRole(MANAGER) {
        IERC20 token = IERC20(_token);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
