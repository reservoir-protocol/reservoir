// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Stablecoin} from "../Stablecoin.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssetAdapter} from "src/interfaces/IAssetAdapter.sol";

contract EthenaSUSDEAdapter is IAssetAdapter, AccessControl {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("asset.adapter.manager"));

    bytes32 public constant CONTROLLER =
        keccak256(abi.encode("asset.adapter.controller"));

    IERC20 public immutable underlying;
    IERC4626 public immutable vault;
    uint256 public immutable duration;

    IOracle public immutable underlyingPriceOracle;
    IOracle public immutable fundPriceOracle;

    uint256 public underlyingRiskWeight; // 100% = 1e6
    uint256 public fundRiskWeight; // 100% = 1e6

    constructor(
        address _admin,
        address _underlyingAddr,
        address _vaultAddr,
        // address _underlyingPriceOracleAddr,
        // address _fundPriceOracleAddr,
        uint256 _duration
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        underlying = IERC20(_underlyingAddr);
        vault = IERC4626(_vaultAddr);
        duration = _duration;

        underlyingPriceOracle = IOracle(_underlyingPriceOracleAddr);
        fundPriceOracle = IOracle(_fundPriceOracleAddr);
    }

    function allocate(uint256) external {}

    function withdraw(uint256) external {}

    function deposit(uint256) external {}

    function redeem(uint256) external {}

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

    function underlyingTotalValue() external view returns (uint256) {
        return _underlyingTotalValue();
    }

    function _underlyingTotalValue() private view returns (uint256) {
        return _underlyingValue(0);
    }

    function underlyingValue(uint256 amount) external view returns (uint256) {
        return _underlyingValue(amount);
    }

    function _underlyingValue(uint256 amount) private view returns (uint256) {
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
        // return (_fundPriceOracleLatestAnswer() * amount) / 1e8;
        return vault.previewDeposit(underlying.totalBalance(address(this)));
    }

    function fundBalance() external view returns (uint256) {
        return _fundBalance();
    }

    function _fundBalance() private view returns (uint256) {
        return vault.balanceOf(address(this));
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

    function recover(address _token) external onlyRole(MANAGER) {
        IERC20 token = IERC20(_token);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
