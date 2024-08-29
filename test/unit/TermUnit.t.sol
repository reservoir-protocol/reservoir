// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Term} from "src/Term.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TermUnitTest is Test {
    Term public term;

    struct IdAndAmount {
        // Avoiding overflow
        uint128 id;
        uint128 amount;
    }

    mapping(uint256 => uint256) public idToAmount;

    function setUp() external {
        term = new Term(address(this), "uri");
        term.grantRole(term.MINTER(), address(this));

        // For test coverage
        term.supportsInterface(0x12345678);
    }

    function testInitialState(address _admin, string memory _uri) external {
        term = new Term(_admin, _uri);

        assertTrue(term.hasRole(0x00, _admin));
        assertEq(term.uri(0), _uri);
    }

    function testMint(uint256 id, uint128 amount) external {
        term.mint(address(this), id, amount);
        assertEq(term.balanceOf(address(this), id), amount);
        assertEq(term.totalSupply(id), amount);

        term.mint(address(2), id, amount);
        assertEq(term.balanceOf(address(2), id), amount);
        assertEq(term.totalSupply(id), uint256(amount) * 2);
    }

    function testMintUnauthorized(
        address wallet,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(wallet != address(this));

        vm.prank(wallet);
        vm.expectRevert();
        term.mint(address(this), id, amount);
    }

    function testMintBatch(IdAndAmount[] memory data) external {
        vm.assume(data.length < 6 && data.length > 0);

        uint256[] memory ids = new uint256[](data.length);
        uint256[] memory amounts = new uint256[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            uint256 id = uint256(data[i].id);
            uint256 amount = uint256(data[i].amount);

            idToAmount[id] += amount;

            ids[i] = id;
            amounts[i] = amount;
        }

        term.mintBatch(address(this), ids, amounts);

        for (uint256 i = 0; i < data.length; i++) {
            uint256 id = uint256(data[i].id);

            assertEq(term.balanceOf(address(this), id), idToAmount[id]);
            assertEq(term.totalSupply(id), idToAmount[id]);
        }
    }

    function testMintBatchUnauthorized(
        address wallet,
        IdAndAmount[] memory data
    ) external {
        vm.assume(data.length < 6 && data.length > 0);
        vm.assume(wallet != address(this));

        uint256[] memory ids = new uint256[](data.length);
        uint256[] memory amounts = new uint256[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            uint256 id = uint256(data[i].id);
            uint256 amount = uint256(data[i].amount);

            idToAmount[id] += amount;

            ids[i] = id;
            amounts[i] = amount;
        }

        vm.prank(wallet);
        vm.expectRevert();
        term.mintBatch(address(this), ids, amounts);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
