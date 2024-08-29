// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Savingcoin} from "src/Savingcoin.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TermUnitTest is Test {
    Savingcoin public savingcoin;

    address public minter = address(1);

    function setUp() external {
        savingcoin = new Savingcoin(
            address(this),
            "Reservoir Savingcoin",
            "srUSD"
        );

        savingcoin.grantRole(savingcoin.MINTER(), minter);
    }

    function testInitialState(
        address _admin,
        string memory _name,
        string memory _symbol
    ) external {
        savingcoin = new Savingcoin(_admin, _name, _symbol);

        assertTrue(savingcoin.hasRole(savingcoin.DEFAULT_ADMIN_ROLE(), _admin));
        assertEq(savingcoin.name(), _name);
        assertEq(savingcoin.symbol(), _symbol);
    }

    function testMint(address account, uint256 amount) external {
        vm.assume(account != address(0));

        vm.prank(minter);
        savingcoin.mint(account, amount);
        assertEq(savingcoin.balanceOf(account), amount);
    }

    function testMintUnauthorized(
        address _minter,
        address account,
        uint256 amount
    ) external {
        vm.assume(_minter != minter);

        vm.expectRevert();
        vm.prank(_minter);
        savingcoin.mint(account, amount);
    }
}
