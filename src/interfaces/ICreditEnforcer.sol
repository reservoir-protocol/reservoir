// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IPegStabilityModule} from "./IPegStabilityModule.sol";
import {ITermIssuer} from "./ITermIssuer.sol";

interface ICreditEnforcer {
    function mintTerm(uint256, uint256) external returns (uint256);

    function psm() external view returns (IPegStabilityModule);

    function termIssuer() external view returns (ITermIssuer);
}
