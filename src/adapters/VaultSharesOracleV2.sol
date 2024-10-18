// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VaultSharesOracleV2 is IOracle {
    AggregatorV3Interface public immutable underlyingAssetAggregator;
    IERC4626 public immutable vault;
    uint8 public immutable underlyingDecimals;

    constructor(
        AggregatorV3Interface _underlyingAssetAggregator,
        IERC4626 _vault,
        uint8 _underlyingDecimals
    ) {
        underlyingAssetAggregator = _underlyingAssetAggregator;
        vault = _vault;
        underlyingDecimals = _underlyingDecimals;
    }

    function latestAnswer() external view returns (int256) {
        int256 answer;
        uint256 updatedAt;

        (, answer, , updatedAt, ) = underlyingAssetAggregator.latestRoundData();

        int256 finalizedAnswer = (block.timestamp > 1.1 days + updatedAt)
            ? int256(1e8)
            : answer;

        return
            (finalizedAnswer * int256(vault.convertToAssets(1e18))) /
            int256(10 ** underlyingDecimals);
    }
}
