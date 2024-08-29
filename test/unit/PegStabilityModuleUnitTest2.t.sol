// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MockV3Aggregator} from "chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {PegStabilityModule} from "src/PegStabilityModule.sol";

import {IToken} from "src/interfaces/IToken.sol";

import {console} from "forge-std/console.sol";
import {Test, stdError} from "forge-std/Test.sol";

contract MockStablecoin {
    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply;

    function setTotalSupply(uint256 supply) external {
        totalSupply = supply;
    }

    function mint(address account, uint256 amount) external {
        totalSupply += amount;
        balanceOf[account] += amount;
    }

    function burnFrom(address account, uint256 amount) public virtual {
        totalSupply -= amount;
        balanceOf[account] -= amount;
    }
}

contract ERC20DecimalsMockWithFees is ERC20DecimalsMock {
    uint256 public immutable fees; // 1e6 = 100%

    constructor(
        uint8 _decimals,
        uint256 _fees
    ) ERC20DecimalsMock("Test TOKEN", "TST", _decimals) {
        fees = _fees;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 totalFeeAmount = (amount * fees) / 1e6;
        uint256 amountAfterFees = amount - totalFeeAmount;

        _burn(from, amount);
        _mint(to, amountAfterFees);

        return true;
    }
}

// Test immutable decimals and addresses
contract PegStabilityModuleUnitTest2 is Test {
    ERC20DecimalsMock usdc;
    MockV3Aggregator usdcAggregator;

    MockStablecoin rusd;

    PegStabilityModule psm;

    uint256 public constant MAX_USDC_AMOUNT = 1e24;

    function setUp() external {
        usdcAggregator = new MockV3Aggregator(8, 1e8);

        rusd = new MockStablecoin();
    }

    function testMint(uint8 decimals, uint128 amount) external {
        vm.assume(decimals <= 18);

        _setup(decimals);

        usdc.mint(address(this), amount);
        usdc.approve(address(psm), amount);

        assertEq(usdc.balanceOf(address(this)), amount);
        assertEq(usdc.balanceOf(address(psm)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        psm.mint(address(this), address(this), amount);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(psm)), amount);
        assertEq(
            rusd.balanceOf(address(this)),
            amount * (10 ** (18 - decimals))
        );
    }

    function testRedeem(uint8 decimals, uint128 amount) external {
        vm.assume(decimals <= 18);

        _setup(decimals);

        rusd.mint(address(this), type(uint256).max);

        usdc.mint(address(psm), amount);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(psm)), amount);
        assertEq(rusd.balanceOf(address(this)), type(uint256).max);

        psm.redeem(amount);

        assertEq(usdc.balanceOf(address(this)), amount);
        assertEq(usdc.balanceOf(address(psm)), 0);
        assertEq(
            rusd.balanceOf(address(this)),
            type(uint256).max - (amount * (10 ** (18 - decimals)))
        );
    }

    function testMintWithTransferFromFees(
        uint8 decimals,
        uint32 fees,
        uint128 amount
    ) external {
        vm.assume(decimals <= 18);
        vm.assume(fees <= 1e6);

        usdc = new ERC20DecimalsMockWithFees(decimals, fees);
        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );
        psm.grantRole(psm.CONTROLLER(), address(this));

        usdc.mint(address(this), amount);
        usdc.approve(address(psm), amount);

        assertEq(usdc.balanceOf(address(this)), amount);
        assertEq(usdc.balanceOf(address(psm)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        psm.mint(address(this), address(this), amount);

        uint256 totalFee = (uint256(amount) * fees) / 1e6;

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(psm)), amount - totalFee);
        assertEq(
            rusd.balanceOf(address(this)),
            (amount - totalFee) * (10 ** (18 - decimals))
        );
    }

    function _setup(uint8 _decimals) internal {
        usdc = new ERC20DecimalsMock("USD Coin Mock", "USDC", _decimals);
        psm = new PegStabilityModule(
            address(this),
            address(usdcAggregator),
            IToken(address(rusd)),
            IERC20(address(usdc))
        );
        psm.grantRole(psm.CONTROLLER(), address(this));
    }
}
