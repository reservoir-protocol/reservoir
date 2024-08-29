// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IToken} from "./IToken.sol";
import {ITerm} from "../Term.sol";

interface ITermIssuer {
    event MintTerm(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 principle,
        uint256 cost,
        uint256 timestamp
    );

    event RedeemTerm(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 principle,
        uint256 timestamp
    );

    function mint(
        address,
        address,
        uint256,
        uint256
    ) external returns (uint256);

    function redeem(uint256, uint256) external;

    function redeem(address, uint256, uint256) external;

    function applyDiscount(
        uint256,
        uint256,
        uint256
    ) external view returns (uint256);

    function getDiscountRate(uint256 id) external view returns (uint256);

    function latestID() external view returns (uint256);

    function earliestID() external view returns (uint256);

    function maturityTimestamp(uint256) external view returns (uint256);

    function totalSupply(uint256) external view returns (uint256);

    function totalDebt() external view returns (uint256);

    function rusd() external view returns (IToken);

    function term() external view returns (ITerm);
}
