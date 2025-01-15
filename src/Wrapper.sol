// SPDX-License-Identifier: MIT

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

import {IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

contract Wrapper is ERC4626 {
    constructor(
        string memory name,
        string memory symbol,
        IERC20Metadata asset
    ) ERC20(name, symbol) ERC4626(asset) {}
}
