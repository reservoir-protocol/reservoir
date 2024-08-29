// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ITerm} from "src/interfaces/ITerm.sol";

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155Burnable} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract Term is AccessControl, ERC1155Supply, ERC1155Burnable {
    bytes32 public constant MINTER = keccak256(abi.encode("term.minter"));

    constructor(address admin, string memory uri) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Increase specific token's total supply
    /// @param to address to increment the token balance
    /// @param id token identifier
    /// @param amount quantity of token added
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyRole(MINTER) {
        _mint(to, id, amount, "");
    }

    /// @notice Increase multiple token's total supply in batch
    /// @param to address to increment the token balance
    /// @param ids array of token identifiers
    /// @param amounts array of quantity of token added
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyRole(MINTER) {
        _mintBatch(to, ids, amounts, "");
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        // TODO: Combine with `AccessControl`

        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        ERC1155Supply._beforeTokenTransfer(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }
}
