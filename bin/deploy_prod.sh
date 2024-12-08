#!/usr/bin/env bash

source .env

# deploy() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # -  -  -  -  -  -  -  - C R E D I T - E N F O R C E R -  -  -  -  -  -  -  - #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# setDuration() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setDuration(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${DURATION} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setAssetRatioMin() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setAssetRatioMin(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${ASSET_RATIO_MIN} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setEquityRatioMin() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setEquityRatioMin(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${EQUITY_RATIO_MIN} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setLiquidityRatioMin() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setLiquidityRatioMin(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${LIQUIDITY_RATIO_MIN} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setSMDebtMax() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setSMDebtMax(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${SM_DEBT_MAX} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setPSMDebtMax() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setPSMDebtMax(address,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${SM_DEBT_MAX} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# setTermDebtMax() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setTermDebtMax(address,uint256,uint256)" ${CREDIT_ENFORCER_ADDRESS} ${TERM_ID} ${TERM_DEBT_MAX} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# addAssetAdapter() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "addAssetAdapter(address,address)" ${CREDIT_ENFORCER_ADDRESS} ${FUND_ADAPTER_ADDRESS} \
#     --fork-url ${RPC_URL} --private-key ${$PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #                   P E G - S T A B I L I T Y - M O D U L E                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# setUSDCRiskWeight() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setUSDCRiskWeight(address,uint256)" ${PEG_STABILITY_MODULE_ADDRESS} 1000 \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #                          S A V I N G - M O D U L E                          #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# update() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "update(address,uint256)" ${SAVING_MODULE_ADDRESS} ${SM_SAVING_RATE} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #                            T E R M - I S S U E R                            #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# setDiscountRate() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "setDiscountRate(address,uint256,uint256)" \
#         ${TERM_ISSUER_ADDRESS} ${TERM_INDEX} ${TERM_DISCOUNT_RATE} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #                           F U N D - A D A P T E R                           #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# deployFund() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "deployFund(address,address,string,string)" \
#         ${OWNER} ${USDC_ADDRESS} "${FUND_NAME}" "${FUND_SYMBOL}" \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# deployAssetAdapter() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "deployAssetAdapter(address,address,address,address,uint256)" \
#         ${ADMIN} ${USDC_ADDRESS} ${FUND_ADDRESS} ${USDC_AGGREGATOR_ADDRESS} ${DURATION} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #                         M O R P H O - A D A P T E R                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# deployAssetAdapter() {
#     forge script script/Reservoir.s.sol:ReservoirScript \
#     --sig "deployMorphoUnderlyingAdapter(address,address,address,address,uint256)" \
#         ${ADMIN} ${UNDERLYING_ADDRESS} ${VAULT_ADDRESS} ${UNDERLYING_AGGREGATOR_ADDRESS} ${DURATION} \
#     --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
#     --broadcast
# }

deployMorphoRUSDAdapter() {
    forge script script/Reservoir.s.sol:ReservoirScript \
    --sig "deployMorphoRUSDAdapter(address,address,address,address,uint256)" \
        ${ADMIN} ${RUSD_ADDRESS} ${FUND_ADDRESS} ${USDC_AGGREGATOR_ADDRESS} ${DURATION} \
    --fork-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow --skip-simulation \
    --broadcast
}
