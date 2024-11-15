// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ITermIssuer} from "src/TermIssuer.sol";
import {ICreditEnforcer} from "src/CreditEnforcer.sol";

contract CalcAggregator {
    struct TermToken {
        uint256 id;
        uint256 maturityTimestamp;
        uint256 discountRate;
    }


    ITermIssuer public immutable termIssuer;
    ICreditEnforcer public immutable creditEnforcer;

    constructor(ICreditEnforcer creditEnforcer_) {
        creditEnforcer = creditEnforcer_;
        termIssuer = creditEnforcer_.termIssuer();

        // Check non zero address ...
    }

    /// @notice Get the earliest term available
    /// @return id of the earliest term
    function getCurrentId() external view returns (uint256) {
        return termIssuer.earliestID();
    }

    /// @notice Get the latest term available
    /// @return id of the latest term
    function getLastId() external view returns (uint256) {
        return termIssuer.latestID();
    }

    /// @notice Get currently available terms
    /// @return termTokens list of terms
    function getCurrentOffers()
        external
        view
        returns (TermToken[] memory termTokens)
    {
        uint256 latestID = termIssuer.latestID();
        uint256 earliestID = termIssuer.earliestID();

        uint256 length = latestID - earliestID + 1;

        termTokens = new TermToken[](length);
        for (uint256 i = 0; i < length; i++) {
            TermToken memory token = _getTerm(earliestID + i);
            termTokens[i] = token;
        }
    }

    /// @notice Get the term details
    /// @param id term identifier
    function getTerm(uint256 id) external view returns (TermToken memory) {
        return _getTerm(id);
    }

    function _getTerm(
        uint256 id
    ) private view returns (TermToken memory termToken) {
        termToken.id = id;
        termToken.discountRate = termIssuer.getDiscountRate(id);
        termToken.maturityTimestamp = termIssuer.maturityTimestamp(id);
    }

    function getTermAmount(
        uint256 id,
        uint256 amount
    ) external view returns (uint256) {
        return _getTermAmount(id, amount);
    }

    function _getTermAmount(
        uint256 id,
        uint256 amount
    ) private view returns (uint256) {
        (uint256 cost, ) = _getQuote(id, 1e36);

        return (amount * 1e36) / cost;
    }

    /// @notice Get the cost and profit for the term's specific amount
    /// @param id term identifier
    /// @param amount amount of term
    function getQuote(
        uint256 id,
        uint256 amount
    ) external view returns (uint256, uint256) {
        if (id < termIssuer.earliestID() || id > termIssuer.latestID()) {
            return (type(uint256).max, 0);
        }
        return _getQuote(id, amount);
    }

    function _getQuote(
        uint256 id,
        uint256 amount
    ) private view returns (uint256 cost, uint256 profit) {
        uint256 mTimestamp;
        uint256 discountRate;

        mTimestamp = termIssuer.maturityTimestamp(id);
        discountRate = termIssuer.getDiscountRate(id);

        cost += termIssuer.applyDiscount(amount, mTimestamp, discountRate);

        profit = amount - cost;
    }
}
