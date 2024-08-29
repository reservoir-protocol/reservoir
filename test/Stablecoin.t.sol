// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {StorageSlot} from "openzeppelin-contracts/contracts/utils/StorageSlot.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {Stablecoin} from "src/Stablecoin.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract StablecoinV2 is Stablecoin, Ownable, ERC20Pausable {
    constructor(
        address owner,
        string memory name,
        string memory symbol
    ) Stablecoin(owner, name, symbol) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Pausable, ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}

contract StablecoinTest is Test {
    Stablecoin usdr;

    function setUp() external {
        usdr = new Stablecoin(address(this), "Reservoir Stablecoin", "rUSD");
    }

    function testInitialState() external {
        assertTrue(usdr.hasRole(usdr.DEFAULT_ADMIN_ROLE(), address(this)));

        assertTrue(usdr.hasRole(0x00, address(this)));
        assertFalse(usdr.hasRole(usdr.MINTER(), address(this)));

        assertEq(usdr.symbol(), "rUSD");
        assertEq(usdr.name(), "Reservoir Stablecoin");
    }

    function testFlow() external {
        address eoa1 = vm.addr(1);
        address eoa2 = vm.addr(2);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(this)), 20),
                " is missing role ",
                Strings.toHexString(uint256(usdr.MINTER()), 32)
            )
        );

        usdr.mint(eoa1, 2_000e18);
        usdr.grantRole(usdr.MINTER(), address(this));

        assertEq(usdr.balanceOf(eoa1), 0);
        assertEq(usdr.balanceOf(eoa2), 0);

        assertEq(usdr.totalSupply(), 0);

        usdr.mint(eoa1, 2_000e18);

        vm.prank(eoa1);
        usdr.transfer(eoa2, 1_000e18);

        assertEq(usdr.balanceOf(eoa1), 1_000e18);
        assertEq(usdr.balanceOf(eoa2), 1_000e18);

        assertEq(usdr.totalSupply(), 2_000e18);
    }
}
