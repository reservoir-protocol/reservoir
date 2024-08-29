// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface ISavingModule {
    event Mint(
        address indexed from,
        address indexed to,
        uint256 mintAmount,
        uint256 burnAmount,
        uint256 timestamp
    );

    event Redeem(
        address indexed from,
        address indexed to,
        uint256 redeemAmount,
        uint256 burnAmount,
        uint256 timestamp
    );

    event Update(
        uint256 compoundFactorAccum,
        uint256 currentRate,
        uint256 rate,
        uint256 timestamp
    );

    function mint(address, address, uint256) external;

    function rusdTotalLiability() external view returns (uint256);

    function totalDebt() external view returns (uint256);
}
