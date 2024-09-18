// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {MorphoUnderlyingAdapter} from "src/adapters/MorphoUnderlyingAdapter.sol";
import {VaultSharesOracle} from "src/adapters/VaultSharesOracle.sol";
import {Stablecoin} from "src/Stablecoin.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

address constant CHAINLINK_USDC_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
ERC20 constant usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
IERC4626 constant metamorphoSteakhouseUsdc = IERC4626(
    0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB
);

contract MorphoUnderlyingAdapterTest is Test {
    event Allocate(address indexed signer, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed signer, uint256 amount, uint256 timestamp);
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);
    event UnderlyingRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);
    event FundRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);

    MorphoUnderlyingAdapter public adapter;
    VaultSharesOracle public vaultSharesOracle;

    uint256 public constant INITIAL_DURATION = 1 days;

    address public eoa1 = vm.addr(1);

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL);

        // Deply Oracle for the Vault Shares
        vaultSharesOracle = new VaultSharesOracle(
            AggregatorV3Interface(CHAINLINK_USDC_FEED),
            metamorphoSteakhouseUsdc
        );

        // Deploy and Configure Morpho Adapter
        adapter = new MorphoUnderlyingAdapter(
            address(this),
            address(usdc),
            address(metamorphoSteakhouseUsdc),
            CHAINLINK_USDC_FEED,
            address(vaultSharesOracle),
            INITIAL_DURATION
        );
        adapter.grantRole(adapter.CONTROLLER(), address(this));
        adapter.grantRole(adapter.MANAGER(), address(this));
    }

    function testInitialBalance() external {
        assertTrue(adapter.hasRole(0x0, address(this)));
        assertTrue(adapter.hasRole(adapter.CONTROLLER(), address(this)));
        assertTrue(adapter.hasRole(adapter.MANAGER(), address(this)));

        assertEq(adapter.duration(), INITIAL_DURATION);

        assertEq(address(adapter.underlyingPriceOracle()), CHAINLINK_USDC_FEED);
        assertEq(
            address(adapter.fundPriceOracle()),
            address(vaultSharesOracle)
        );

        assertEq(adapter.fundRiskWeight(), 0e6);
        assertEq(adapter.underlyingRiskWeight(), 0e6);

        assertEq(address(adapter.underlying()), address(usdc));
        assertEq(address(adapter.fund()), address(metamorphoSteakhouseUsdc));
    }

    function testAllocate(uint64 amount, uint32 underlyingRiskWeight) external {
        vm.assume(underlyingRiskWeight < 1e6);

        adapter.setUnderlyingRiskWeight(underlyingRiskWeight);

        deal(address(usdc), address(this), amount, true);

        assertEq(usdc.balanceOf(address(adapter)), 0);

        usdc.approve(address(adapter), amount);

        vm.expectEmit(true, true, true, true);
        emit Allocate(address(this), amount, block.timestamp);
        adapter.allocate(amount);

        assertEq(usdc.balanceOf(address(adapter)), amount);
        assertEq(usdc.balanceOf(address(this)), 0);

        assertEq(adapter.totalValue(), adapter.underlyingTotalValue());
        assertEq(adapter.totalRiskValue(), adapter.underlyingTotalRiskValue());
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (_underlyingUsdPrice() * amount * 1e12 * underlyingRiskWeight) /
                1e8 /
                1e6
        );
        assertEq(
            adapter.underlyingTotalValue(),
            (_underlyingUsdPrice() * amount * 1e12) / 1e8
        );
        assertEq(adapter.underlyingBalance(), usdc.balanceOf(address(adapter)));
        assertEq(adapter.fundTotalRiskValue(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundBalance(), 0);
    }

    function testAllocateWithInsufficientAllowance(uint64 amount) external {
        vm.assume(amount > 0);

        deal(address(usdc), address(this), amount, true);

        vm.expectRevert();
        adapter.allocate(amount);
    }

    function testAllocateWithInsufficientBalance(uint64 amount) external {
        vm.assume(amount > 0);

        usdc.approve(address(adapter), amount);

        vm.expectRevert();
        adapter.allocate(amount);
    }

    function testWithdraw(
        uint64 allocateAmount,
        uint64 withdrawAmount,
        uint32 underlyingRiskWeight
    ) external {
        vm.assume(allocateAmount >= withdrawAmount);
        vm.assume(underlyingRiskWeight < 1e6);

        adapter.setUnderlyingRiskWeight(underlyingRiskWeight);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(this), withdrawAmount, block.timestamp);
        adapter.withdraw(withdrawAmount);

        assertEq(
            usdc.balanceOf(address(adapter)),
            allocateAmount - withdrawAmount
        );
        assertEq(usdc.balanceOf(address(this)), withdrawAmount);

        assertEq(adapter.totalValue(), adapter.underlyingTotalValue());
        assertEq(adapter.totalRiskValue(), adapter.underlyingTotalRiskValue());
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (_underlyingUsdPrice() *
                (allocateAmount - withdrawAmount) *
                1e12 *
                underlyingRiskWeight) /
                1e8 /
                1e6
        );
        assertEq(
            adapter.underlyingTotalValue(),
            (_underlyingUsdPrice() * (allocateAmount - withdrawAmount) * 1e12) /
                1e8
        );
        assertEq(adapter.underlyingBalance(), usdc.balanceOf(address(adapter)));
        assertEq(adapter.fundTotalRiskValue(), 0);
        assertEq(adapter.fundTotalValue(), 0);
        assertEq(adapter.fundBalance(), 0);
    }

    function testWithdrawInsufficientBalance(
        uint64 allocateAmount,
        uint64 withdrawAmount
    ) external {
        vm.assume(allocateAmount < withdrawAmount);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        vm.expectRevert();
        adapter.withdraw(withdrawAmount);
    }

    function testWithdrawUnauthorized(
        uint64 allocateAmount,
        uint64 withdrawAmount
    ) external {
        vm.assume(allocateAmount > 0 && withdrawAmount > 0);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        adapter.revokeRole(adapter.CONTROLLER(), address(this));

        vm.expectRevert();
        adapter.withdraw(withdrawAmount);
    }

    function testDeposit(
        uint64 allocateAmount,
        uint64 depositAmount,
        uint32 underlyingRiskWeight,
        uint32 fundRiskWeight
    ) external {
        vm.assume(allocateAmount > 0);
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(underlyingRiskWeight < 1e6);
        vm.assume(fundRiskWeight < 1e6);

        adapter.setUnderlyingRiskWeight(underlyingRiskWeight);
        adapter.setFundRiskWeight(fundRiskWeight);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), depositAmount, block.timestamp);
        adapter.deposit(depositAmount);

        assertEq(
            usdc.balanceOf(address(adapter)),
            allocateAmount - depositAmount
        );
        assertEq(usdc.balanceOf(address(this)), 0);
        assertApproxEqAbs(
            metamorphoSteakhouseUsdc.convertToAssets(
                metamorphoSteakhouseUsdc.balanceOf(address(adapter))
            ),
            depositAmount,
            1
        );

        assertEq(
            adapter.totalValue(),
            adapter.underlyingTotalValue() + adapter.fundTotalValue()
        );
        assertEq(
            adapter.totalRiskValue(),
            adapter.underlyingTotalRiskValue() + adapter.fundTotalRiskValue()
        );
        assertEq(
            adapter.underlyingTotalRiskValue(),
            (_underlyingUsdPrice() *
                (allocateAmount - depositAmount) *
                1e12 *
                underlyingRiskWeight) /
                1e8 /
                1e6
        );
        assertEq(
            adapter.underlyingTotalValue(),
            (_underlyingUsdPrice() * (allocateAmount - depositAmount) * 1e12) /
                1e8
        );
        assertEq(adapter.underlyingBalance(), usdc.balanceOf(address(adapter)));
        assertApproxEqRel(
            adapter.fundTotalRiskValue(),
            (_fundUsdPrice() *
                metamorphoSteakhouseUsdc.balanceOf(address(adapter)) *
                fundRiskWeight) / (1e8 * 1e6),
            0.00001e18
        );
        assertEq(
            adapter.fundTotalValue(),
            (_fundUsdPrice() *
                metamorphoSteakhouseUsdc.balanceOf(address(adapter))) / 1e8
        );
        assertEq(
            adapter.fundBalance(),
            metamorphoSteakhouseUsdc.balanceOf(address(adapter))
        );
    }

    function testDepositInsufficientBalance(
        uint64 allocateAmount,
        uint64 depositAmount
    ) external {
        vm.assume(allocateAmount > 0);
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount > allocateAmount);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        vm.expectRevert();
        adapter.deposit(depositAmount);
    }

    function testDepositUnauthorized(uint64 amount) external {
        vm.assume(amount > 0);

        deal(address(usdc), address(this), amount, true);

        usdc.approve(address(adapter), amount);
        adapter.allocate(amount);

        adapter.revokeRole(adapter.CONTROLLER(), address(this));

        vm.expectRevert();
        adapter.deposit(amount);
    }

    function testRedeem(
        uint64 allocateAmount,
        uint64 depositAmount,
        uint64 redeemAmountOfShares,
        uint32 underlyingRiskWeight,
        uint32 fundRiskWeight
    ) external {
        vm.assume(allocateAmount > 1);
        vm.assume(depositAmount > 1);
        vm.assume(redeemAmountOfShares > 1);
        vm.assume(depositAmount <= allocateAmount);

        vm.assume(underlyingRiskWeight < 1e6);
        vm.assume(fundRiskWeight < 1e6);

        adapter.setUnderlyingRiskWeight(underlyingRiskWeight);
        adapter.setFundRiskWeight(fundRiskWeight);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        adapter.deposit(depositAmount);

        vm.assume(redeemAmountOfShares <= adapter.fundBalance());

        uint256 assetEquivalentOfShares = metamorphoSteakhouseUsdc
            .convertToAssets(redeemAmountOfShares);

        vm.expectEmit(true, true, true, true);
        emit Redeem(address(this), redeemAmountOfShares, block.timestamp);
        adapter.redeem(redeemAmountOfShares);

        assertEq(
            usdc.balanceOf(address(adapter)),
            allocateAmount - depositAmount + assetEquivalentOfShares
        );

        assertEq(usdc.balanceOf(address(this)), 0);
        assertApproxEqAbs(
            metamorphoSteakhouseUsdc.convertToAssets(
                metamorphoSteakhouseUsdc.balanceOf(address(adapter))
            ),
            depositAmount - assetEquivalentOfShares,
            1
        );

        assertEq(
            adapter.totalValue(),
            adapter.underlyingTotalValue() + adapter.fundTotalValue()
        );
        assertEq(
            adapter.totalRiskValue(),
            adapter.underlyingTotalRiskValue() + adapter.fundTotalRiskValue()
        );

        assertEq(
            adapter.underlyingTotalRiskValue(),
            (_underlyingUsdPrice() *
                (allocateAmount - depositAmount + assetEquivalentOfShares) *
                underlyingRiskWeight *
                1e12) / (1e6 * 1e8)
        );
        assertEq(
            adapter.underlyingTotalValue(),
            (_underlyingUsdPrice() *
                (allocateAmount - depositAmount + assetEquivalentOfShares) *
                1e12) / 1e8
        );
        assertEq(adapter.underlyingBalance(), usdc.balanceOf(address(adapter)));
        assertApproxEqAbs(
            adapter.fundTotalRiskValue(),
            (_fundUsdPrice() *
                metamorphoSteakhouseUsdc.balanceOf(address(adapter)) *
                fundRiskWeight) / (1e8 * 1e6),
            1
        );
        assertEq(
            adapter.fundTotalValue(),
            (_fundUsdPrice() *
                metamorphoSteakhouseUsdc.balanceOf(address(adapter))) / 1e8
        );
        assertEq(
            adapter.fundBalance(),
            metamorphoSteakhouseUsdc.balanceOf(address(adapter))
        );
    }

    function testRedeemInsufficientBalance(
        uint64 allocateAmount,
        uint64 depositAmount,
        uint64 redeemAmountOfShares
    ) external {
        vm.assume(allocateAmount > 1);
        vm.assume(depositAmount > 1);
        vm.assume(depositAmount <= allocateAmount);

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        adapter.deposit(depositAmount);

        vm.assume(redeemAmountOfShares > adapter.fundBalance());

        vm.expectRevert();
        adapter.redeem(redeemAmountOfShares);
    }

    function testRedeemUnauthorized(
        uint64 allocateAmount,
        uint64 depositAmount,
        uint64 redeemAmount
    ) external {
        vm.assume(allocateAmount > 1);
        vm.assume(depositAmount > 1);
        vm.assume(redeemAmount > 1);
        vm.assume(depositAmount <= allocateAmount);
        vm.assume(redeemAmount <= depositAmount - 1); // On deposit, 1 is lost

        deal(address(usdc), address(this), allocateAmount, true);

        usdc.approve(address(adapter), allocateAmount);
        adapter.allocate(allocateAmount);

        adapter.deposit(depositAmount);

        adapter.revokeRole(adapter.CONTROLLER(), address(this));

        vm.expectRevert();
        adapter.redeem(redeemAmount);
    }

    function testSetUnderlyingRiskWeight(uint256 riskWeight) external {
        if (riskWeight < 1e6) {
            vm.expectEmit(true, true, true, true);
            emit UnderlyingRiskWeightUpdate(riskWeight, block.timestamp);
            adapter.setUnderlyingRiskWeight(riskWeight);
            assertEq(adapter.underlyingRiskWeight(), riskWeight);
        } else {
            vm.expectRevert("FA: Risk Weight can not be above 100%");
            adapter.setUnderlyingRiskWeight(riskWeight);
        }
    }

    function testSetUnderlyingiskWeightUnauthorized(
        uint256 riskWeight
    ) external {
        adapter.revokeRole(adapter.MANAGER(), address(this));

        vm.expectRevert();
        adapter.setUnderlyingRiskWeight(riskWeight);
    }

    function testSetFundRiskWeight(uint256 riskWeight) external {
        if (riskWeight < 1e6) {
            vm.expectEmit(true, true, true, true);
            emit FundRiskWeightUpdate(riskWeight, block.timestamp);
            adapter.setFundRiskWeight(riskWeight);
            assertEq(adapter.fundRiskWeight(), riskWeight);
        } else {
            vm.expectRevert("FA: Risk Weight can not be above 100%");
            adapter.setFundRiskWeight(riskWeight);
        }
    }

    function testSetFundRiskWeightUnauthorized(uint256 riskWeight) external {
        adapter.revokeRole(adapter.MANAGER(), address(this));

        vm.expectRevert();
        adapter.setFundRiskWeight(riskWeight);
    }

    function testRecover(uint256 _amount, address _reciever) external {
        vm.assume(_reciever != address(0));
        vm.assume(_reciever != address(adapter));

        ERC20 testToken = new ERC20("Test Token", "TTT");
        deal(address(testToken), address(adapter), _amount);
        assertEq(testToken.balanceOf(_reciever), 0);
        assertEq(testToken.balanceOf(address(adapter)), _amount);
        adapter.recover(address(testToken), _reciever);
        assertEq(testToken.balanceOf(_reciever), _amount);
        assertEq(testToken.balanceOf(address(adapter)), 0);
    }

    function testRecoverAsNonOwner() external {
        adapter.revokeRole(adapter.MANAGER(), address(this));

        vm.expectRevert();
        adapter.recover(address(usdc), address(this));
    }

    function _underlyingUsdPrice() internal view returns (uint256) {
        int256 latestAnswer = IOracle(CHAINLINK_USDC_FEED).latestAnswer();

        return latestAnswer > 0 ? uint256(latestAnswer) : 0;
    }

    function _fundUsdPrice() internal view returns (uint256) {
        int256 latestAnswer = vaultSharesOracle.latestAnswer();

        return latestAnswer > 0 ? uint256(latestAnswer) : 0;
    }
}
