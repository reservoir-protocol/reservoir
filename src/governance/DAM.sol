// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Votes, ERC20, ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";

contract DAM is AccessControl, ERC20Burnable, ERC20Votes {
    uint256 private constant supply = 1_000_000_000e18;

    bytes32 public constant MINTER = keccak256(abi.encode("dam.minter"));

    constructor(
        address admin_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        _mint(admin_, supply);
    }

    /// @notice Increase token total supply
    /// @param account Address to increment the token balance
    /// @param amount Quantity of token added
    function mint(address account, uint256 amount) external onlyRole(MINTER) {
        _mint(account, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(account, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
