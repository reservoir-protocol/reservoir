// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VaultSharesOracle is IOracle {
    AggregatorV3Interface public immutable underlyingAssetAggregator;
    IERC4626 public immutable vault;

    constructor(
        AggregatorV3Interface _underlyingAssetAggregator,
        IERC4626 _vault
    ) {
        underlyingAssetAggregator = _underlyingAssetAggregator;
        vault = _vault;
    }

    function latestAnswer() external view returns (int256) {
        int256 answer;
        uint256 updatedAt;

        (, answer, , updatedAt, ) = underlyingAssetAggregator.latestRoundData();

        int256 finalizedAnswer = (block.timestamp > 1.1 days + updatedAt)
            ? int256(1e8)
            : answer;

        return (finalizedAnswer * int256(vault.convertToAssets(1e18))) / 1e6;
    }
}
