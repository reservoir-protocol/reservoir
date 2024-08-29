// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

import {ITermIssuer} from "src/TermIssuer.sol";
import {ICreditEnforcer} from "src/CreditEnforcer.sol";

import {IAccountManager} from "src/interfaces/IAccountManager.sol";

contract AccountManager is IAccountManager {
    IERC20 public immutable rusd;
    IERC1155 public immutable term;

    ITermIssuer public immutable termIssuer;
    ICreditEnforcer public immutable creditEnforcer;

    uint256 public immutable couponRate; // 0e12

    mapping(address => uint256[]) public accountList;
    mapping(address => mapping(uint256 => Position)) public accountMap;

    constructor(ICreditEnforcer creditEnforcer_, uint256 _couponRate) {
        creditEnforcer = creditEnforcer_;
        termIssuer = creditEnforcer_.termIssuer();

        rusd = IERC20(address(termIssuer.rusd()));
        term = IERC1155(address(termIssuer.term()));

        couponRate = _couponRate;

        rusd.approve(address(creditEnforcer_), type(uint256).max);
        term.setApprovalForAll(address(termIssuer), true);
    }

    /// @notice Mint the term
    /// @param id term identifier
    /// @param amount amount of term to be minted
    function mintTerm(uint256 id, uint256 amount) external {
        Position storage position = accountMap[msg.sender][id];

        if (position.principle == 0) {
            accountList[msg.sender].push(id);

            position.index = accountList[msg.sender].length - 1;
        }

        _mintTerm(position, msg.sender, id, amount);
    }

    /// @notice Mint the term to specific account
    /// @param to account to receive term
    /// @param id term identifier
    /// @param amount amount of term to be minted
    function mintTerm(address to, uint256 id, uint256 amount) external {
        Position storage position = accountMap[to][id];

        if (position.principle == 0) {
            accountList[to].push(id);

            position.index = accountList[to].length - 1;
        }

        _mintTerm(position, msg.sender, id, amount);
    }

    function _mintTerm(
        Position storage position,
        address from,
        uint256 id,
        uint256 amount
    ) private {
        uint256 couponValue = (couponRate * amount) / (4 * 1e12);

        uint256 earliestID = termIssuer.earliestID();
        uint256 couponCount = id >= earliestID ? id - earliestID + 1 : 0;

        position.coupons = position.coupons.length == 0
            ? new uint256[](couponCount)
            : position.coupons;

        (uint256 cost, ) = _getQuote(id, amount);

        rusd.approve(address(termIssuer), cost);
        rusd.transferFrom(from, address(this), cost);

        for (uint256 i = 0; i < couponCount; i++) {
            creditEnforcer.mintTerm(id - i, couponValue);
            position.coupons[i] += couponValue;
        }

        creditEnforcer.mintTerm(id, amount);
        position.principle += amount;
    }

    /// @notice Claim the coupon of the term
    /// @param id term identifier
    function claim(uint256 id) external {
        Position storage position = accountMap[msg.sender][id];

        uint256 couponValue = _claim(position.coupons, msg.sender, id);

        emit ClaimCoupon(
            msg.sender,
            msg.sender,
            id,
            couponValue,
            block.timestamp
        );
    }

    /// @notice Claim the coupon of the term to specific account
    /// @param to account to recieve coupon
    /// @param id term identifier
    function claim(address to, uint256 id) external {
        Position storage position = accountMap[msg.sender][id];

        uint256 couponValue = _claim(position.coupons, to, id);

        emit ClaimCoupon(msg.sender, to, id, couponValue, block.timestamp);
    }

    function _claim(
        uint256[] storage coupons,
        address to,
        uint256 id
    ) private returns (uint256 couponValue) {
        uint256 length = coupons.length;

        (bool success, string memory message) = _canClaim(coupons, id);
        require(success, message);

        uint256 claimId = id + 1 - length;
        couponValue = coupons[length - 1];

        coupons.pop();

        termIssuer.redeem(to, claimId, couponValue);
    }

    /// @notice Check if the term's coupon can be claimed for specified account
    /// @param account owner of the term
    /// @param id term identifier
    function canClaim(
        address account,
        uint256 id
    ) external view returns (bool, string memory) {
        Position memory position = accountMap[account][id];

        return _canClaim(position.coupons, id);
    }

    function _canClaim(
        uint256[] memory coupons,
        uint256 id
    ) private view returns (bool, string memory) {
        uint256 length = coupons.length;

        if (length == 0 || termIssuer.earliestID() + length <= id + 1) {
            return (false, "AM: no coupon available");
        }

        return (true, "");
    }

    /// @notice Redeem the term
    /// @param id term identifier
    function redeem(uint256 id) external {
        Position storage position = accountMap[msg.sender][id];

        _redeem(position, msg.sender, msg.sender, id);
    }

    /// @notice Redeem the term to specific account
    /// @param to account to receive term
    /// @param id term identifier
    function redeem(address to, uint256 id) external {
        Position storage position = accountMap[msg.sender][id];

        _redeem(position, msg.sender, to, id);
    }

    function _redeem(
        Position storage position,
        address from,
        address to,
        uint256 id
    ) private {
        uint256 index;
        uint256 lastIndex;

        uint256[] storage coupons = position.coupons;

        uint256 principle = position.principle;
        require(coupons.length == 0, "AM: all coupons must be claimed");

        lastIndex = accountList[from].length - 1;

        uint256 idOfLastIndexTerm = accountList[from][lastIndex];

        index = accountMap[from][id].index;

        accountMap[from][idOfLastIndexTerm].index = index;

        accountList[from][index] = accountList[from][lastIndex];

        accountList[from].pop();

        delete accountMap[from][id];

        termIssuer.redeem(to, id, principle);
    }

    /// @notice Get user position for a specific term
    /// @param account owner of the term
    /// @param id term identifier
    /// @return position of the term
    function getUserPosition(
        address account,
        uint256 id
    ) external view returns (Position memory) {
        return accountMap[account][id];
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
        termToken.maturityTimestamp = termIssuer.maturityTimestamp(id);
        termToken.discountRate = termIssuer.getDiscountRate(id);
        termToken.couponRate = couponRate;

        uint256 earliestId = termIssuer.earliestID();
        uint256 latestId = termIssuer.latestID();

        if (id < earliestId || id > latestId) return termToken;

        uint256 length = id - earliestId + 1;

        termToken.coupons = new TermCoupon[](length);

        for (uint256 i = 0; i < length; i++) {
            termToken.coupons[i].rate = couponRate;
            termToken.coupons[i].discountRate = termIssuer.getDiscountRate(
                id - i
            );
            termToken.coupons[i].claimTimestamp = termIssuer.maturityTimestamp(
                id - i
            );
        }
    }

    /// @notice Get the coupons list for the term owned by an account
    /// @param account owner of the term
    /// @param id term identifier
    /// @return coupons list of coupons
    function getCoupons(
        address account,
        uint256 id
    ) external view returns (TermCoupon[] memory) {
        return _getCoupons(account, id);
    }

    function _getCoupons(
        address account,
        uint256 id
    ) private view returns (TermCoupon[] memory coupons) {
        Position memory position = accountMap[account][id];

        uint256 length = position.coupons.length;

        coupons = new TermCoupon[](length);

        for (uint256 i = 0; i < length; i++) {
            coupons[i].rate = couponRate;
            coupons[i].discountRate = termIssuer.getDiscountRate(id - i);
            coupons[i].claimTimestamp = termIssuer.maturityTimestamp(id - i);
        }
    }

    function getTermCouponAmount(
        uint256 id,
        uint256 amount
    ) external view returns (uint256) {
        return _getTermCouponAmount(id, amount);
    }

    function _getTermCouponAmount(
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

        uint256 couponValue = (couponRate * amount) / (4 * 1e12);

        uint256 earliestID = termIssuer.earliestID();
        uint256 couponCount = id >= earliestID ? id - earliestID + 1 : 0;

        for (uint256 i = 0; i < couponCount; i++) {
            profit += couponValue;
            mTimestamp = termIssuer.maturityTimestamp(id - i);
            discountRate = termIssuer.getDiscountRate(id - i);
            cost += termIssuer.applyDiscount(
                couponValue,
                mTimestamp,
                discountRate
            );
        }

        mTimestamp = termIssuer.maturityTimestamp(id);
        discountRate = termIssuer.getDiscountRate(id);

        cost += termIssuer.applyDiscount(amount, mTimestamp, discountRate);

        profit += amount;
        profit -= cost;
    }

    /// @notice Get the maturity timestamp for the term
    /// @param id term identifier
    /// @return maturity timestamp
    function getMaturityTimestamp(uint256 id) external view returns (uint256) {
        return termIssuer.maturityTimestamp(id);
    }

    /// @notice get the total debt of the term issuer
    /// @return total debt
    function getTermDebtTotal() external view returns (uint256) {
        return termIssuer.totalDebt();
    }

    /// @notice get the number of terms owned by an account
    /// @param account owner of the term
    /// @return number of terms
    function accountListLength(
        address account
    ) external view returns (uint256) {
        return accountList[account].length;
    }

    /// @notice get the current holdings of an account
    /// @param account owner of the term
    /// @return positions list of positions
    function getCurrentHoldings(
        address account
    ) external view returns (Position[] memory positions) {
        uint256 id;
        uint256 length = accountList[account].length;

        positions = new Position[](length);

        for (uint256 i = 0; i < length; i++) {
            id = accountList[account][i];
            positions[i] = accountMap[account][id];
        }
    }

    /// @notice get the list of terms owned by an account
    /// @param account owner of the term
    /// @return list of term identifiers
    function getAccountList(
        address account
    ) external view returns (uint256[] memory) {
        return accountList[account];
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
