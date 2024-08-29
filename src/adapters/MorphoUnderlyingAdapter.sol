// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssetAdapter} from "src/interfaces/IAssetAdapter.sol";

contract MorphoUnderlyingAdapter is AccessControl, IAssetAdapter {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("asset.adapter.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("asset.adapter.controller"));

    uint256 public immutable duration;

    IOracle public immutable underlyingPriceOracle;
    IOracle public immutable fundPriceOracle;

    uint256 public underlyingRiskWeight = 0e6; // 100% = 1e6
    uint256 public fundRiskWeight = 0e6; // 100% = 1e6

    IERC4626 public immutable fund;
    IERC20 public immutable underlying;

    uint8 public immutable DECIMAL_FACTOR;

    constructor(
        address _admin,
        address _underlyingAddr,
        address _fundAddr,
        address _underlyingPriceOracleAddr,
        address _fundPriceOracleAddr,
        uint256 _duration
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        underlying = IERC20(_underlyingAddr);
        fund = IERC4626(_fundAddr);
        duration = _duration;

        DECIMAL_FACTOR = IERC20Metadata(address(underlying)).decimals();

        underlyingPriceOracle = IOracle(_underlyingPriceOracleAddr);
        fundPriceOracle = IOracle(_fundPriceOracleAddr);
    }

    function allocate(uint256 _assets) external {
        underlying.transferFrom(msg.sender, address(this), _assets);

        emit Allocate(msg.sender, _assets, block.timestamp);
    }

    function withdraw(uint256 _assets) external onlyRole(CONTROLLER) {
        underlying.transfer(msg.sender, _assets);

        emit Withdraw(msg.sender, _assets, block.timestamp);
    }

    function deposit(uint256 _assets) public onlyRole(CONTROLLER) {
        underlying.approve(address(fund), _assets);
        fund.deposit(_assets, address(this));

        emit Deposit(msg.sender, _assets, block.timestamp);
    }

    function redeem(uint256 _shares) public onlyRole(CONTROLLER) {
        fund.redeem(_shares, address(this), address(this));

        emit Redeem(msg.sender, _shares, block.timestamp);
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
        total += _underlyingTotalValue();
        total += _fundTotalValue();
    }

    function totalRiskValue() external view returns (uint256 total) {
        total += _underlyingTotalRiskValue();
        total += _fundTotalRiskValue();
    }

    function underlyingTotalRiskValue() external view returns (uint256) {
        return _underlyingTotalRiskValue();
    }

    function _underlyingTotalRiskValue() private view returns (uint256) {
        return _underlyingRiskValue(_underlyingBalance());
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
        return _underlyingValue(_underlyingBalance());
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

    function recover(
        address _token,
        address _reciever
    ) external onlyRole(MANAGER) {
        IERC20 token = IERC20(_token);

        token.transfer(_reciever, token.balanceOf(address(this)));
    }
}
