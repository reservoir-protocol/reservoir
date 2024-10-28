// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {MorphoRUSDAdapter} from "src/adapters/MorphoRUSDAdapter.sol";
import {VaultSharesOracleV2} from "src/adapters/VaultSharesOracleV2.sol";
import {Stablecoin} from "src/Stablecoin.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

address constant CHAINLINK_USDC_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
address constant RUSD_METAMORPHO_VAULT = 0xBeEf11eCb698f4B5378685C05A210bdF71093521;
address constant RUSD_ADDRESS = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;
address constant RUSD_DEFAULT_ADMIN = 0xb7570e32dED63B25163369D5eb4D8e89E70e5602;

contract MorphoRUSDAdapterTest is Test {
    event Deposit(address indexed signer, uint256 amount, uint256 timestamp);
    event Redeem(address indexed signer, uint256 amount, uint256 timestamp);
    event UnderlyingRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);
    event FundRiskWeightUpdate(uint256 riskWeight, uint256 timestamp);

    Stablecoin public rusd = Stablecoin(RUSD_ADDRESS);

    IERC4626 public metamorpho = IERC4626(RUSD_METAMORPHO_VAULT);

    uint256 public constant TESTING_CAP = 5_000_000_000e18;

    MorphoRUSDAdapter public adapter;
    VaultSharesOracleV2 public vaultSharesOracleV2;

    uint256 public constant INITIAL_DURATION = 1 days;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    // avoid stack too deep errors for testDepositRedeemFlow test
    uint256 depositShares1;
    uint256 redeemShares1;
    uint256 depositShares2;
    uint256 redeemShares2;

    function setUp() external {
        vm.createSelectFork(MAINNET_RPC_URL);

        bytes32 RUSD_MINTER = rusd.MINTER();

        vm.prank(RUSD_DEFAULT_ADMIN);
        rusd.grantRole(RUSD_MINTER, address(this));

        // Deply Oracle for the Vault Shares
        vaultSharesOracleV2 = new VaultSharesOracleV2(
            AggregatorV3Interface(CHAINLINK_USDC_FEED),
            metamorpho,
            18
        );

        // Deploy and Configure Morpho Adapter
        adapter = new MorphoRUSDAdapter(
            address(this),
            address(rusd),
            address(metamorpho),
            CHAINLINK_USDC_FEED,
            address(vaultSharesOracleV2),
            INITIAL_DURATION
        );
        adapter.grantRole(adapter.CONTROLLER(), address(this));
        adapter.grantRole(adapter.MANAGER(), address(this));

        // Configure rUSD roles
        vm.prank(RUSD_DEFAULT_ADMIN);
        rusd.grantRole(RUSD_MINTER, address(adapter));
        vm.prank(RUSD_DEFAULT_ADMIN);
        rusd.grantRole(RUSD_MINTER, address(this));
    }

    function testInitialBalance() external {
        assertTrue(adapter.hasRole(0x0, address(this)));
        assertTrue(adapter.hasRole(adapter.CONTROLLER(), address(this)));
        assertTrue(adapter.hasRole(adapter.MANAGER(), address(this)));

        assertEq(adapter.duration(), INITIAL_DURATION);

        assertEq(address(adapter.underlyingPriceOracle()), CHAINLINK_USDC_FEED);
        assertEq(
            address(adapter.fundPriceOracle()),
            address(vaultSharesOracleV2)
        );

        assertEq(adapter.fundRiskWeight(), 0e6);
        assertEq(adapter.underlyingRiskWeight(), 0e6);

        assertEq(address(adapter.underlying()), address(rusd));
        assertEq(address(adapter.vault()), address(metamorpho));
    }

    function testDepositRedeemFlow(
        uint256 depositAmount1,
        uint256 redeemAmount1,
        uint256 depositAmount2,
        uint256 redeemAmount2,
        uint32 riskWeight
    ) external {
        vm.assume(depositAmount1 <= 1_000_000_000e18);
        vm.assume(redeemAmount1 <= depositAmount1);
        vm.assume(depositAmount2 <= 1_000_000_000e18);
        vm.assume(redeemAmount2 <= depositAmount2);
        vm.assume(riskWeight < 1e6);

        adapter.setFundRiskWeight(riskWeight);

        uint256 initialRusdTotalSupply = rusd.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), depositAmount1, block.timestamp);
        adapter.deposit(depositAmount1);

        depositShares1 = metamorpho.convertToShares(depositAmount1);

        assertApproxEqAbs(
            metamorpho.convertToAssets(metamorpho.balanceOf(address(adapter))),
            depositAmount1,
            10
        );
        assertEq(rusd.balanceOf(address(adapter)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        assertApproxEqAbs(
            rusd.totalSupply(),
            initialRusdTotalSupply + depositAmount1,
            10
        );

        assertApproxEqAbs(
            adapter.totalValue(),
            (uint256(vaultSharesOracleV2.latestAnswer()) * depositShares1) /
                1e8,
            10
        );
        assertEq(adapter.fundTotalValue(), adapter.totalValue());

        assertApproxEqAbs(
            adapter.totalRiskValue(),
            (riskWeight *
                ((uint256(vaultSharesOracleV2.latestAnswer()) *
                    depositShares1) / 1e8)) / 1e6,
            10
        );
        assertEq(adapter.fundTotalRiskValue(), adapter.totalRiskValue());
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.fundBalance(), metamorpho.balanceOf(address(adapter)));

        vm.expectEmit(true, true, true, true);
        emit Redeem(
            address(this),
            metamorpho.convertToShares(redeemAmount1),
            block.timestamp
        );
        adapter.redeem(metamorpho.convertToShares(redeemAmount1));

        depositShares1 = metamorpho.convertToShares(depositAmount1);
        redeemShares1 = metamorpho.convertToShares(redeemAmount1);

        assertApproxEqAbs(
            metamorpho.convertToAssets(metamorpho.balanceOf(address(adapter))),
            depositAmount1 - redeemAmount1,
            10
        );
        assertEq(rusd.balanceOf(address(adapter)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        assertApproxEqAbs(
            rusd.totalSupply(),
            initialRusdTotalSupply + depositAmount1 - redeemAmount1,
            10
        );

        assertApproxEqAbs(
            adapter.totalValue(),
            (uint256(vaultSharesOracleV2.latestAnswer()) *
                (depositShares1 - redeemShares1)) / 1e8,
            10
        );
        assertEq(adapter.fundTotalValue(), adapter.totalValue());
        assertApproxEqAbs(
            adapter.totalRiskValue(),
            (riskWeight *
                ((uint256(vaultSharesOracleV2.latestAnswer()) *
                    (depositShares1 - redeemShares1)) / 1e8)) / 1e6,
            10
        );
        assertEq(adapter.fundTotalRiskValue(), adapter.totalRiskValue());
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.fundBalance(), metamorpho.balanceOf(address(adapter)));

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), depositAmount2, block.timestamp);
        adapter.deposit(depositAmount2);

        depositShares1 = metamorpho.convertToShares(depositAmount1);
        redeemShares1 = metamorpho.convertToShares(redeemAmount1);
        depositShares2 = metamorpho.convertToShares(depositAmount2);

        assertApproxEqAbs(
            metamorpho.convertToAssets(metamorpho.balanceOf(address(adapter))),
            depositAmount1 - redeemAmount1 + depositAmount2,
            10
        );
        assertEq(rusd.balanceOf(address(adapter)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        assertApproxEqAbs(
            rusd.totalSupply(),
            initialRusdTotalSupply +
                depositAmount1 -
                redeemAmount1 +
                depositAmount2,
            10
        );

        assertApproxEqAbs(
            adapter.totalValue(),
            (uint256(vaultSharesOracleV2.latestAnswer()) *
                (depositShares1 - redeemShares1 + depositShares2)) / 1e8,
            10
        );
        assertEq(adapter.fundTotalValue(), adapter.totalValue());
        assertApproxEqAbs(
            adapter.totalRiskValue(),
            (riskWeight *
                ((uint256(vaultSharesOracleV2.latestAnswer()) *
                    (depositShares1 - redeemShares1 + depositShares2)) / 1e8)) /
                1e6,
            10
        );
        assertEq(adapter.fundTotalRiskValue(), adapter.totalRiskValue());
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.fundBalance(), metamorpho.balanceOf(address(adapter)));

        vm.expectEmit(true, true, true, true);
        emit Redeem(
            address(this),
            metamorpho.convertToShares(redeemAmount2),
            block.timestamp
        );
        adapter.redeem(metamorpho.convertToShares(redeemAmount2));

        depositShares1 = metamorpho.convertToShares(depositAmount1);
        redeemShares1 = metamorpho.convertToShares(redeemAmount1);
        depositShares2 = metamorpho.convertToShares(depositAmount2);
        redeemShares2 = metamorpho.convertToShares(redeemAmount2);

        assertApproxEqAbs(
            metamorpho.convertToAssets(metamorpho.balanceOf(address(adapter))),
            depositAmount1 - redeemAmount1 + depositAmount2 - redeemAmount2,
            10
        );
        assertEq(rusd.balanceOf(address(adapter)), 0);
        assertEq(rusd.balanceOf(address(this)), 0);

        assertApproxEqAbs(
            rusd.totalSupply(),
            initialRusdTotalSupply +
                depositAmount1 -
                redeemAmount1 +
                depositAmount2 -
                redeemAmount2,
            10
        );

        assertApproxEqAbs(
            adapter.totalValue(),
            (uint256(vaultSharesOracleV2.latestAnswer()) *
                (depositShares1 -
                    redeemShares1 +
                    depositShares2 -
                    redeemShares2)) / 1e8,
            10
        );
        assertEq(adapter.fundTotalValue(), adapter.totalValue());
        assertApproxEqAbs(
            adapter.totalRiskValue(),
            (riskWeight *
                ((uint256(vaultSharesOracleV2.latestAnswer()) *
                    (depositShares1 -
                        redeemShares1 +
                        depositShares2 -
                        redeemShares2)) / 1e8)) / 1e6,
            10
        );
        assertEq(adapter.fundTotalRiskValue(), adapter.totalRiskValue());
        assertEq(adapter.underlyingTotalRiskValue(), 0);
        assertEq(adapter.underlyingTotalValue(), 0);
        assertEq(adapter.underlyingBalance(), 0);
        assertEq(adapter.fundBalance(), metamorpho.balanceOf(address(adapter)));
    }

    function test_redeem_with_accidental_sent_tokens(
        uint256 depositAmount,
        uint256 redeemAmount,
        uint256 accidentalySentAmount
    ) external {
        vm.assume(depositAmount <= 1_000_000_000e18);
        vm.assume(redeemAmount <= depositAmount);
        vm.assume(accidentalySentAmount <= 1_000_000_000e18);

        adapter.deposit(depositAmount);

        deal(address(rusd), address(this), accidentalySentAmount, true);
        rusd.transfer(address(adapter), accidentalySentAmount);

        adapter.redeem(redeemAmount);

        assertEq(rusd.balanceOf(address(adapter)), accidentalySentAmount);
    }

    function testDepositUnauthorized(uint256 amount) external {
        adapter.revokeRole(adapter.CONTROLLER(), address(this));

        vm.expectRevert();
        adapter.deposit(amount);
    }

    //? NEED TO KNOW THE CAP OR THIS TEST
    function testRedeemMoreThenDeposited(
        uint256 depositAmount,
        uint256 redeemAmount
    ) external {
        vm.assume(depositAmount <= TESTING_CAP);
        vm.assume(redeemAmount > depositAmount);

        adapter.deposit(depositAmount);

        vm.expectRevert();
        adapter.redeem(redeemAmount);
    }

    function testRedeemUnauthorized(uint256 amount) external {
        adapter.revokeRole(adapter.CONTROLLER(), address(this));

        vm.expectRevert();
        adapter.redeem(amount);
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

    function test_recover(uint256 _amount) external {
        ERC20 testToken = new ERC20("Test Token", "TTT");

        deal(address(testToken), address(adapter), _amount);

        assertEq(testToken.balanceOf(address(this)), 0);
        assertEq(testToken.balanceOf(address(adapter)), _amount);

        adapter.recover(address(testToken));

        assertEq(testToken.balanceOf(address(this)), _amount);
        assertEq(testToken.balanceOf(address(adapter)), 0);
    }

    function test_recover_as_non_owner() external {
        adapter.revokeRole(adapter.MANAGER(), address(this));

        vm.expectRevert();
        adapter.recover(address(rusd));
    }
}
