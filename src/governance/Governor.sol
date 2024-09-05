// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import {Governor} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorVotes} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorSettings} from "openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";

import {GovernorCountingSimple} from "openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorTimelockControl} from "openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotesQuorumFraction} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract ReservoirGovernor is
    Governor,
    GovernorVotes,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorTimelockControl,
    GovernorVotesQuorumFraction
{
    constructor(
        string memory name_,
        IVotes token_,
        TimelockController timelock_,
        uint256 votingDelay_,
        uint256 votingPeriod_,
        uint256 proposalThreshold_,
        uint256 quorumNumeratorValue_
    )
        Governor(name_)
        GovernorVotes(token_)
        GovernorSettings(votingDelay_, votingPeriod_, proposalThreshold_)
        GovernorTimelockControl(timelock_)
        GovernorVotesQuorumFraction(quorumNumeratorValue_)
    {}

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

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
