// SPDX-License-Identifier: MIT

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {ERC1155Supply} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract LiquidTerm is ERC20 {
    uint256 public immutable tokenId;

    IERC1155 public immutable registry;

    constructor(
        IERC1155 _registry,
        uint256 _tokenId
    ) ERC20("Liquid Term", "ltrUSD") {
        registry = _registry;
        tokenId = _tokenId;
    }

    function totalSupply() public view override returns (uint256) {
        try ERC1155Supply(address(registry)).totalSupply(tokenId) returns (
            uint256 amount
        ) {
            return amount;
        } catch {
            return 0;
        }
    }

    function balanceOf(address account) public view override returns (uint256) {
        return registry.balanceOf(account, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        registry.safeTransferFrom(from, to, tokenId, amount, "");
    }
}
