// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IAccountManager {
    event ClaimCoupon(
        address indexed from,
        address indexed to,
        uint256 indexed termId,
        uint256 amount,
        uint256 timestamp
    );

    struct Position {
        uint256 index;
        uint256 principle;
        uint256[] coupons;
    }

    struct TermCoupon {
        uint256 rate;
        uint256 discountRate;
        uint256 claimTimestamp;
    }

    struct TermToken {
        uint256 id;
        uint256 maturityTimestamp;
        uint256 discountRate;
        uint256 couponRate;
        TermCoupon[] coupons;
    }

    function mintTerm(uint256, uint256) external;

    function mintTerm(address, uint256, uint256) external;

    function claim(uint256) external;

    function claim(address, uint256) external;

    function canClaim(
        address,
        uint256
    ) external view returns (bool, string memory);

    function redeem(uint256) external;

    function redeem(address, uint256) external;

    function getUserPosition(
        address,
        uint256
    ) external view returns (Position memory);

    function couponRate() external view returns (uint256);

    function getCurrentId() external view returns (uint256);

    function getLastId() external view returns (uint256);

    function getCurrentOffers() external view returns (TermToken[] memory);

    function getTerm(uint256) external view returns (TermToken memory);

    function getCoupons(
        address,
        uint256
    ) external view returns (TermCoupon[] memory);

    function getQuote(
        uint256,
        uint256
    ) external view returns (uint256, uint256);

    function getMaturityTimestamp(uint256) external view returns (uint256);

    function getTermDebtTotal() external view returns (uint256);
}
