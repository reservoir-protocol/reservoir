// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Savingcoin is AccessControl, ERC20Burnable {
    bytes32 public constant MINTER = keccak256(abi.encode("savingcoin.minter"));

    /// @notice Constructor of the contract
    /// @param admin Specially permissioned address
    /// @param name Description for the token
    /// @param symbol Ticker used for referencing the token
    constructor(
        address admin,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Increase token total supply
    /// @param account Address to increment the token balance
    /// @param amount Quantity of token added
    function mint(address account, uint256 amount) external onlyRole(MINTER) {
        _mint(account, amount);
    }
}
