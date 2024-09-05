// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {ERC20Votes, ERC20, ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";

// burnable, mintable

contract DAM is ERC20Votes {
    uint256 private constant supply = 1_000_000_000e18;

    constructor(/* admin */) ERC20("DAM", "DAM") ERC20Permit("DAM") {
        _mint(msg.sender, supply);
    }

    // mint - - owner

    // burn - -

    // function clock() public view virtual override returns (uint48) {
    //     return SafeCast.toUint48(block.timestamp);
    // }

    // // solhint-disable-next-line func-name-mixedcase
    // function CLOCK_MODE() public view virtual override returns (string memory) {
    //     return "mode=timestamp";
    // }
}
