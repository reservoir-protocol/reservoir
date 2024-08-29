// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IOracle} from "src/interfaces/IOracle.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IAssetAdapter {
    event Allocate(address indexed signer, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed signer, uint256 amount, uint256 timestamp);
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);
    event UnderlyingRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);
    event FundRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);

    function duration() external view returns (uint256);

    function underlyingPriceOracle() external view returns (IOracle);

    function fundPriceOracle() external view returns (IOracle);

    function underlyingRiskWeight() external view returns (uint256);

    function fundRiskWeight() external view returns (uint256);

    //! function fund() external view returns (uint256); DIFFERS IN `ASSETADAPTER` AND MORPHO ADAPTERS

    function underlying() external view returns (IERC20);

    function allocate(uint256) external;

    function withdraw(uint256) external;

    function deposit(uint256) external;

    function redeem(uint256) external;

    function totalValue() external view returns (uint256);

    function totalRiskValue() external view returns (uint256);

    function underlyingTotalRiskValue() external view returns (uint256);

    function underlyingRiskValue(uint256) external view returns (uint256);

    function underlyingTotalValue() external view returns (uint256);

    function underlyingValue(uint256) external view returns (uint256);

    function underlyingBalance() external view returns (uint256);

    function fundTotalRiskValue() external view returns (uint256);

    function fundRiskValue(uint256) external view returns (uint256);

    function fundTotalValue() external view returns (uint256);

    function fundValue(uint256) external view returns (uint256);

    function fundBalance() external view returns (uint256);
}
