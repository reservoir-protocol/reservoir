// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";

import {Governor} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorVotes} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorTimelockControl} from "openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";

contract ReservoirGovernor is GovernorVotes, GovernorTimelockControl {
    constructor(
        string memory name_,
        IVotes token_,
        TimelockController timelock_
    )
        GovernorVotes(token_)
        GovernorTimelockControl(timelock_)
        Governor(name_)
    {}

    // function quorum(uint256) public pure override returns (uint256) {
    //     return 0;
    // }

    // function votingDelay() public pure override returns (uint256) {
    //     return 4;
    // }

    // function votingPeriod() public pure override returns (uint256) {
    //     return 16;
    // }

    // function cancel(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 salt
    // ) public returns (uint256 proposalId) {
    //     return _cancel(targets, values, calldatas, salt);
    // }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
