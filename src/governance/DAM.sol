// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ERC20Votes, ERC20, ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract DAM is AccessControl, ERC20Votes {
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

    /// @notice Decrease token total supply
    /// @param amount Quantity of token deducted
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /// @notice Decrease token total supply
    /// @param account Address to decrement the token balance
    /// @param amount Quantity of token deducted
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
