#!/usr/bin/env bash

source .env

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(string,string,uint8)" \
#         "USD Coin Reservoir Mock" "rUSDC.t" 6) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${USDC_ADDRESS} lib/openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol:ERC20DecimalsMock

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,string,string)" \
#         ${DEPLOYER} "Reservoir Stablecoin" "rUSD") \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${RUSD_ADDRESS} src/Stablecoin.sol:Stablecoin

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,string,string)" \
#         ${DEPLOYER} "Savings rUSD" "srUSD") \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${SRUSD_ADDRESS} src/Savingcoin.sol:Savingcoin

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,string)" \
#         ${DEPLOYER} "https://reservoir.xyz") \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${TERM_ADDRESS} src/Term.sol:Term

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
#         ${DEPLOYER} ${USDC_AGGREGATOR_ADDRESS} ${RUSD_ADDRESS} ${USDC_ADDRESS}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${PEG_STABILITY_MODULE_ADDRESS} src/PegStabilityModule.sol:PegStabilityModule

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,address)" \
#         ${DEPLOYER} ${RUSD_ADDRESS} ${SRUSD_ADDRESS}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${SAVING_MODULE_ADDRESS} src/SavingModule.sol:SavingModule

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,uint256,uint256,address,address)" \
#         ${DEPLOYER} ${DELTA} ${START_DATE} ${TERM_ADDRESS} ${RUSD_ADDRESS}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${TERM_ISSUER_ADDRESS} src/TermIssuer.sol:TermIssuer

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,uint256,address,address)" \
#         ${DEPLOYER} ${USDC_ADDRESS} ${TERM_ISSUER_ADDRESS} ${PEG_STABILITY_MODULE_ADDRESS} ${SAVING_MODULE_ADDRESS}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${CREDIT_ENFORCER_ADDRESS} src/CreditEnforcer.sol:CreditEnforcer

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,uint256)" \
#         ${CREDIT_ENFORCER_ADDRESS} 80000000000) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${ACCOUNT_MANAGER_ADDRESS} src/AccountManager.sol:AccountManager

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,string,string)" \
#         ${OWNER} ${USDC_ADDRESS} "${FUND_NAME}" "${FUND_SYMBOL}") \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${FUND_ADDRESS} lib/offchain-fund/src/OffchainFund.sol:OffchainFund

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
#         ${ADMIN} ${USDC_ADDRESS} ${FUND_ADDRESS} ${USDC_AGGREGATOR_ADDRESS} ${FUND_AGGREGATOR_ADDRESS} ${DURATION}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${FUND_ADAPTER_ADDRESS} src/adapters/AssetAdapter.sol:AssetAdapter

# forge verify-contract --chain-id 137 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address)" ${FUND_ADDRESS}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${FUND_AGGREGATOR_ADDRESS} src/adapters/AssetAdapter.sol:AssetPrice

# forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,uint256)" \
#         ${ADMIN} ${RUSD_ADDRESS} ${FUND_ADDRESS} ${USDC_AGGREGATOR_ADDRESS} ${FUND_AGGREGATOR_ADDRESS} ${DURATION}) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${FUND_ADAPTER_ADDRESS} src/adapters/MorphoRUSDAdapter.sol:MorphoRUSDAdapter

# forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch \
#     --constructor-args $(cast abi-encode "constructor(address,address,uint8)" ${USDC_AGGREGATOR_ADDRESS} ${FUND_ADDRESS} 18) \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
#         ${FUND_AGGREGATOR_ADDRESS} src/adapters/VaultSharesOracleV2.sol:VaultSharesOracleV2

forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch \
    --constructor-args $(cast abi-encode "constructor(address)" 0x4a9770852463ADf95829D516a6CFc49d1d2D8023) \
    --etherscan-api-key ${ETHERSCAN_API_KEY} --compiler-version v0.8.24+commit.e11b9ed9 \
        0x5679EC49dC34308E1552c3162573cf87dba26f59 src/CalcAggregator.sol:CalcAggregator
