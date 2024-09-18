// SPDX-License-Identifier: MIT

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {ERC1155Supply} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract LiquidTerm is ERC20 {
    uint256 public immutable tokenId;

    address public immutable registry;

    constructor(
        string memory name_,
        string memory symbol_,
        address registry_,
        uint256 tokenId_
    ) ERC20(name_, symbol_) {
        registry = registry_;
        tokenId = tokenId_;
    }

    function totalSupply() public view override returns (uint256) {
        return ERC1155Supply(registry).totalSupply(tokenId);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return IERC1155(registry).balanceOf(account, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        IERC1155(registry).safeTransferFrom(from, to, tokenId, amount, "");
    }
}
