// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Stablecoin} from "src/Stablecoin.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TermUnitTest is Test {
    Stablecoin public stablecoin;

    address public minter = address(1);

    function setUp() external {
        stablecoin = new Stablecoin(
            address(this),
            "Reservoir Stablecoin",
            "rUSD"
        );

        stablecoin.grantRole(stablecoin.MINTER(), minter);
    }

    function testInitialState(
        address _admin,
        string memory _name,
        string memory _symbol
    ) external {
        stablecoin = new Stablecoin(_admin, _name, _symbol);

        assertTrue(stablecoin.hasRole(stablecoin.DEFAULT_ADMIN_ROLE(), _admin));
        assertEq(stablecoin.name(), _name);
        assertEq(stablecoin.symbol(), _symbol);
    }

    function testMint(address account, uint256 amount) external {
        vm.assume(account != address(0));

        vm.prank(minter);
        stablecoin.mint(account, amount);
        assertEq(stablecoin.balanceOf(account), amount);
    }

    function testMintUnauthorized(
        address _minter,
        address account,
        uint256 amount
    ) external {
        vm.assume(_minter != minter);

        vm.expectRevert();
        vm.prank(_minter);
        stablecoin.mint(account, amount);
    }
}
