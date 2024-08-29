// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./AccountManagerFuzz.t.sol";

contract AccountManagerTermIssuerCallsTest is AccountManagerFuzzTest {
    function testGetMaturityTimestamp(uint8 _termId) external {
        assertEq(
            accountManager.getMaturityTimestamp(_termId),
            termIssuer.maturityTimestamp(_termId)
        );
    }

    function testGetTermDebtTotal() external {
        assertEq(accountManager.getTermDebtTotal(), termIssuer.totalDebt());
    }
}
