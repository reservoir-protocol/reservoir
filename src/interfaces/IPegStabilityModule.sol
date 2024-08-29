// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IPegStabilityModule {
    event Allocate(address indexed signer, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed signer, uint256 amount, uint256 timestamp);
    event UnderlyingRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);

    event Mint(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    event Redeem(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    function allocate(uint256) external;

    function withdraw(uint256) external;

    function mint(address, address, uint256) external;

    function totalValue() external view returns (uint256);

    function totalRiskValue() external view returns (uint256);

    function underlyingBalance() external view returns (uint256);
}
