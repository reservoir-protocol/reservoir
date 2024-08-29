// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./E2EMain.t.sol";

contract E2EScenarioFuzzTest is E2EMainTest {
    address public constant WALLET_1 = address(1);
    address public constant WALLET_2 = address(2);
    address public constant WALLET_3 = address(3);

    uint256 public constant STARTING_rusd = 10_000_000_000_000e18;

    function testScenarioFuzz(
        uint32 _yield,
        uint64 _cRate,
        uint16 _startingBondId,
        uint128 _w1p1w3p1,
        uint128 _w1p2w2p1
    ) external {
        // _w1p1w3p1 -  Purchase amounts for WALLET_1 and WALLET_3
        // _w1p2w2p1 -  Purchase amounts for WALLET_3 and second purchase amount for WALLET_1

        vm.assume(_startingBondId > 1);
        vm.assume(_w1p1w3p1 > 0 && _w1p1w3p1 < 1_000_000_000e18);
        vm.assume(_w1p2w2p1 > 0 && _w1p2w2p1 < 1_000_000_000e18);
        vm.assume(_cRate < 1e12);

        _setVariables(_startingBondId, _yield, _cRate);

        _mintrusd(WALLET_1, STARTING_rusd / 1e12);
        _mintrusd(WALLET_2, STARTING_rusd / 1e12);
        _mintrusd(WALLET_3, STARTING_rusd / 1e12);

        assertEq(rusd.balanceOf(WALLET_1), STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_2), STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_3), STARTING_rusd);

        _buyBond(WALLET_1, _w1p1w3p1, _bond1(_startingBondId));
        uint256 wallet1cost1 = _applyDiscountFull(
            _w1p1w3p1,
            _bond1(_startingBondId)
        );

        skip(5 days);

        _checkUserState(
            WALLET_1,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet1cost1,
            _w1p1w3p1,
            1,
            _cRate,
            1,
            0
        );
        assertEq(rusd.balanceOf(WALLET_2), STARTING_rusd);
        assertEq(rusd.balanceOf(WALLET_3), STARTING_rusd);

        _buyBond(WALLET_2, _w1p2w2p1, _bond1(_startingBondId));
        uint256 wallet2cost1 = _applyDiscountFull(
            _w1p2w2p1,
            _bond1(_startingBondId)
        );

        skip(5 days);

        _checkUserState(
            WALLET_1,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet1cost1,
            _w1p1w3p1,
            1,
            _cRate,
            1,
            0
        );
        _checkUserState(
            WALLET_2,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet2cost1,
            _w1p2w2p1,
            1,
            _cRate,
            1,
            0
        );
        assertEq(rusd.balanceOf(WALLET_3), STARTING_rusd);

        // TODO: Fix this rate to something realistic

        termIssuer.setDiscountRate(_bond1(_startingBondId), 0.000131103 * 1e9);

        _buyBond(WALLET_1, _w1p2w2p1, _bond1(_startingBondId));
        uint256 wallet1cost2 = _applyDiscountFull(
            _w1p2w2p1,
            _bond1(_startingBondId)
        );

        _buyBond(WALLET_3, _w1p1w3p1, _bond2(_startingBondId));
        uint256 wallet3cost1 = _applyDiscountFull(
            _w1p1w3p1,
            _bond2(_startingBondId)
        );

        _checkUserState(
            WALLET_1,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet1cost1 + wallet1cost2,
            _w1p1w3p1 + _w1p2w2p1,
            1,
            _cRate,
            1,
            0
        );
        _checkUserState(
            WALLET_2,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet2cost1,
            _w1p2w2p1,
            1,
            _cRate,
            1,
            0
        );
        _checkUserState(
            WALLET_3,
            STARTING_rusd,
            _bond2(_startingBondId),
            false,
            wallet3cost1,
            _w1p1w3p1,
            1,
            _cRate,
            5,
            0
        );

        skip(DELTA - 10 days);

        _claimCoupon(WALLET_1, _bond1(_startingBondId));
        _redeemBond(WALLET_1, _bond1(_startingBondId));
        _claimCoupon(WALLET_3, _bond2(_startingBondId));

        _checkUserState(
            WALLET_1,
            STARTING_rusd,
            _bond1(_startingBondId),
            true,
            wallet1cost1 + wallet1cost2,
            _w1p1w3p1 + _w1p2w2p1,
            0,
            _cRate,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            STARTING_rusd,
            _bond1(_startingBondId),
            false,
            wallet2cost1,
            _w1p2w2p1,
            1,
            _cRate,
            1,
            0
        );
        _checkUserState(
            WALLET_3,
            STARTING_rusd,
            _bond2(_startingBondId),
            false,
            wallet3cost1,
            _w1p1w3p1,
            1,
            _cRate,
            4,
            1
        );

        skip(DELTA * 4);

        _claimCoupon(WALLET_2, _bond1(_startingBondId));
        _redeemBond(WALLET_2, _bond1(_startingBondId));
        _claimCoupon(WALLET_3, _bond2(_startingBondId));
        _claimCoupon(WALLET_3, _bond2(_startingBondId));
        _claimCoupon(WALLET_3, _bond2(_startingBondId));
        _claimCoupon(WALLET_3, _bond2(_startingBondId));
        _redeemBond(WALLET_3, _bond2(_startingBondId));

        _checkUserState(
            WALLET_1,
            STARTING_rusd,
            _bond1(_startingBondId),
            true,
            wallet1cost1 + wallet1cost2,
            _w1p1w3p1 + _w1p2w2p1,
            0,
            _cRate,
            0,
            1
        );
        _checkUserState(
            WALLET_2,
            STARTING_rusd,
            _bond1(_startingBondId),
            true,
            wallet2cost1,
            _w1p2w2p1,
            0,
            _cRate,
            0,
            1
        );
        _checkUserState(
            WALLET_3,
            STARTING_rusd,
            _bond2(_startingBondId),
            true,
            wallet3cost1,
            _w1p1w3p1,
            0,
            _cRate,
            0,
            5
        );
    }

    // If I just add variables like uint256 BOND_1 = _startingBondId inside the test function, it throws stack too deep error

    function _bond1(uint16 _startingBondId) internal pure returns (uint256) {
        return _startingBondId;
    }

    function _bond2(uint16 _startingBondId) internal pure returns (uint256) {
        return uint256(_startingBondId) + 4;
    }
}
