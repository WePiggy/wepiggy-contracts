#!/bin/bash
set -x
set -e

#!!!!!!!!!!!!!------- modify here ------#
NETWORK=kovan
TIME_LOCK_ADMIN=
PIGGY_BREEDER_START_BLOCK=
PIGGY_BREEDER__ENABLE_CLAIM_BLOCK=
ETH=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
output_file=deployed.kovan_qa.env

START=`date +%s`

print_progress () {
  printf "\e[0;33m$1\e[0m\n"
}

print_success () {
  printf "\e[4;32m$1\e[0m\n"
}

#npx oz link @openzeppelin/contracts-ethereum-package

npx oz compile --solc-version=0.6.12 --optimizer on

npx oz session --network $NETWORK

#==============================for mock erc20s==============================#
YFII=`npx oz deploy -k regular -n $NETWORK MockERC20 YFII.finance YFII 1e27 18`
print_progress "YFII = $YFII"
echo "YFII=$YFII" >> $output_file

QUSD=`npx oz deploy -k regular -n $NETWORK MockERC20 QUSD\ Stablecoi QUSD 1e27 18`
print_progress "QUSD = $QUSD"
echo "QUSD=$QUSD" >> $output_file

HUSD=`npx oz deploy -k regular -n $NETWORK MockERC20 HUSD HUSD 1e17 8`
print_progress "HUSD = $HUSD"
echo "HUSD=$HUSD" >> $output_file

UNI=`npx oz deploy -k regular -n $NETWORK MockERC20 Uniswap UNI 1e27 18`
print_progress "UNI = $UNI"
echo "UNI=$UNI" >> $output_file

WBTC=`npx oz deploy -k regular -n $NETWORK MockERC20 Wrapped\ BTC WBTC 1e17 8`
print_progress "WBTC = $WBTC"
echo "WBTC=$WBTC" >> $output_file

DAI=`npx oz deploy -k regular -n $NETWORK MockERC20 Dai\ Stablecoin DAI 1e27 18`
print_progress "DAI = $DAI"
echo "DAI=$DAI" >> $output_file

USDT=`npx oz deploy -k regular -n $NETWORK MockERC20 Tether\ USD USDT 1e15 6`
print_progress "USDT = $USDT"
echo "USDT=$USDT" >> $output_file

USDC=`npx oz deploy -k regular -n $NETWORK MockERC20 USD\ Coin USDC 1e15 6`
print_progress "USDC = $USDC"
echo "USDC=$USDC" >> $output_file

#==============================for time lock==============================#
TIME_LOCK=`npx oz deploy -k regular -n $NETWORK Timelock $TIME_LOCK_ADMIN 172800`
print_progress "TIME_LOCK = $TIME_LOCK"
echo "TIME_LOCK=$TIME_LOCK" >> $output_file

#==============================for wpc==============================#
WPC=`npx oz deploy -k regular -n $NETWORK WePiggyToken`
print_progress "WPC = $WPC"
echo "WPC=$WPC" >> $output_file

#==============================for funding manager==============================#
FUNDING_MANAGER=`npx oz deploy -k regular -n $NETWORK FundingManager $WPC`
print_progress "FUNDING_MANAGER = $FUNDING_MANAGER"
echo "FUNDING_MANAGER=$FUNDING_MANAGER" >> $output_file

FUNDING_HOLDER_INSURANCE_PAYMENT=`npx oz deploy -k regular -n $NETWORK FundingHolder $WPC`
print_progress "FUNDING_HOLDER_INSURANCE_PAYMENT = $FUNDING_HOLDER_INSURANCE_PAYMENT"
echo "FUNDING_HOLDER_INSURANCE_PAYMENT=$FUNDING_HOLDER_INSURANCE_PAYMENT" >> $output_file

FUNDING_HOLDER_RESOURCE_EXPANSION=`npx oz deploy -k regular -n $NETWORK FundingHolder $WPC`
print_progress "FUNDING_HOLDER_RESOURCE_EXPANSION = $FUNDING_HOLDER_RESOURCE_EXPANSION"
echo "FUNDING_HOLDER_RESOURCE_EXPANSION=$FUNDING_HOLDER_RESOURCE_EXPANSION" >> $output_file

FUNDING_HOLDER_TEAM_VOTE=`npx oz deploy -k regular -n $NETWORK FundingHolder $WPC`
print_progress "FUNDING_HOLDER_TEAM_VOTE = $FUNDING_HOLDER_TEAM_VOTE"
echo "FUNDING_HOLDER_TEAM_VOTE=$FUNDING_HOLDER_TEAM_VOTE" >> $output_file

FUNDING_HOLDER_TEAM_SPENDING=`npx oz deploy -k regular -n $NETWORK FundingHolder $WPC`
print_progress "FUNDING_HOLDER_TEAM_SPENDING = $FUNDING_HOLDER_TEAM_SPENDING"
echo "FUNDING_HOLDER_TEAM_SPENDING=$FUNDING_HOLDER_TEAM_SPENDING" >> $output_file

FUNDING_HOLDER_COMMUNITY_REWARDS=`npx oz deploy -k regular -n $NETWORK FundingHolder $WPC`
print_progress "FUNDING_HOLDER_COMMUNITY_REWARDS = $FUNDING_HOLDER_COMMUNITY_REWARDS"
echo "FUNDING_HOLDER_COMMUNITY_REWARDS=$FUNDING_HOLDER_COMMUNITY_REWARDS" >> $output_file

# add fundingHolder to fundingManager
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args InsurancePayment,$FUNDING_HOLDER_INSURANCE_PAYMENT,30
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args ResourceExpansion,$FUNDING_HOLDER_RESOURCE_EXPANSION,25
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamVote,$FUNDING_HOLDER_TEAM_VOTE,20
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamSpending,$FUNDING_HOLDER_TEAM_SPENDING,18
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args CommunityRewards,$FUNDING_HOLDER_COMMUNITY_REWARDS,7

#==============================for farm==============================#
PIGGY_BREEDER=`npx oz deploy -k regular -n $NETWORK PiggyBreeder $WPC $FUNDING_MANAGER 1000000000000000000 $PIGGY_BREEDER_START_BLOCK $PIGGY_BREEDER__ENABLE_CLAIM_BLOCK 5760 999 39`
print_progress "PIGGY_BREEDER = $PIGGY_BREEDER"
echo "PIGGY_BREEDER=$PIGGY_BREEDER" >> $output_file

# wpc,grant miner role to piggyBreeder
npx oz send-tx --to $WPC --method grantRole --args 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6,$PIGGY_BREEDER

#==============================price oracle==============================#
SIMPLE_PRICE_ORAClE=`npx oz create -n $NETWORK SimplePriceOracle --init initialize`
print_progress "SIMPLE_PRICE_ORAClE = $SIMPLE_PRICE_ORAClE"
echo "SIMPLE_PRICE_ORAClE=$SIMPLE_PRICE_ORAClE" >> $output_file

# mock send price to SimplePriceOracle
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $ETH,598650000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $DAI,1004481000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $USDT,1000000000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $USDC,1000000000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $WBTC,192191700000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $QUSD,1000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $HUSD,10000000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $YFII,19203710000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $UNI,3931450000000000000

#==============================Comptroller==============================#
COMPTROLLER=`npx oz create -n $NETWORK Comptroller --init initialize`
print_progress "COMPTROLLER = $COMPTROLLER"
echo "COMPTROLLER=$COMPTROLLER" >> $output_file

#==============================rate model==============================#
JUMP_RATE_MODEL=`npx oz create -n $NETWORK JumpRateModel --init initialize --args 0.05e18,0.45e18,0.25e18,0.95e18`
print_progress "JUMP_RATE_MODEL = $JUMP_RATE_MODEL"
echo "JUMP_RATE_MODEL=$JUMP_RATE_MODEL" >> $output_file

#==============================pTokens==============================#
P_ETH=`npx oz create -n $NETWORK PEther --init initialize --args $COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ ETH\",\"pETH\",8`
print_progress "P_ETH = $P_ETH"
echo "P_ETH=$P_ETH" >> $output_file

P_DAI=`npx oz create -n $NETWORK PERC20 --init initialize --args $DAI,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ DAI\",\"pDAI\",8`
print_progress "P_DAI = $P_DAI"
echo "P_DAI=$P_DAI" >> $output_file

P_USDT=`npx oz create -n $NETWORK PERC20 --init initialize --args $USDT,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ USDT\",\"pUSDT\",8`
print_progress "P_USDT = $P_USDT"
echo "P_USDT=$P_USDT" >> $output_file

P_USDC=`npx oz create -n $NETWORK PERC20 --init initialize --args $USDC,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ USDC\",\"pUSDC\",8`
print_progress "P_USDC = $P_USDC"
echo "P_USDC=$P_USDC" >> $output_file

P_WBTC=`npx oz create -n $NETWORK PERC20 --init initialize --args $WBTC,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ WBTC\",\"pWBTC\",8`
print_progress "P_WBTC = $P_WBTC"
echo "P_WBTC=$P_WBTC" >> $output_file

P_YFII=`npx oz create -n $NETWORK PERC20 --init initialize --args $YFII,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ YFII\",\"pYFII\",8`
print_progress "P_YFII = $P_YFII"
echo "P_YFII=$P_YFII" >> $output_file

P_QUSD=`npx oz create -n $NETWORK PERC20 --init initialize --args $QUSD,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ QUSD\",\"pQUSD\",8`
print_progress "P_QUSD = $P_QUSD"
echo "P_QUSD=$P_QUSD" >> $output_file

P_HUSD=`npx oz create -n $NETWORK PERC20 --init initialize --args $HUSD,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ HUSD\",\"pHUSD\",8`
print_progress "P_HUSD = $P_HUSD"
echo "P_HUSD=$P_HUSD" >> $output_file

P_UNI=`npx oz create -n $NETWORK PERC20 --init initialize --args $UNI,$COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ UNI\",\"pUNI\",8`
print_progress "P_UNI = $P_UNI"
echo "P_UNI=$P_UNI" >> $output_file

# config pToken
npx oz send-tx --to $P_ETH --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_DAI --method _setReserveFactor --args 0.05e18
npx oz send-tx --to $P_USDT --method _setReserveFactor --args 0.2e18
npx oz send-tx --to $P_USDC --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_WBTC --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_QUSD --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_HUSD --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_YFII --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_UNI --method _setReserveFactor --args 0.5e18

#==============================config Comptroller==============================#
npx oz send-tx --to $COMPTROLLER --method _setMaxAssets --args 20
npx oz send-tx --to $COMPTROLLER --method _setPriceOracle --args $SIMPLE_PRICE_ORAClE
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_ETH
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_DAI
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_USDT
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_USDC
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_WBTC
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_YFII
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_QUSD
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_HUSD
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_UNI
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_ETH,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_DAI,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_USDT,0
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_USDC,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_WBTC,0.6e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_YFII,0.6e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_QUSD,0.6e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_HUSD,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_UNI,0.6e18
npx oz send-tx --to $COMPTROLLER --method _setCloseFactor --args 0.5e18
npx oz send-tx --to $COMPTROLLER --method _setDistributeWpcPaused --args true


#==============================PiggyDistribution==============================#
MOCK_TOKEN=`npx oz deploy -k regular -n $NETWORK MockERC20 Mock\ Token MC 1e27 18`
print_progress "MOCK_TOKEN = $MOCK_TOKEN"
echo "MOCK_TOKEN=$MOCK_TOKEN" >> $output_file

PIGGY_DISTRIBUTION=`npx oz create -n $NETWORK PiggyDistribution --init initialize --args $MOCK_TOKEN,$PIGGY_BREEDER,$COMPTROLLER`
print_progress "PIGGY_DISTRIBUTION = $PIGGY_DISTRIBUTION"
echo "PIGGY_DISTRIBUTION=$PIGGY_DISTRIBUTION" >> $output_file

npx oz send-tx --to $COMPTROLLER --method _setPiggyDistribution --args $PIGGY_DISTRIBUTION
npx oz send-tx --to $PIGGY_DISTRIBUTION --method _addWpcMarkets --args [$P_ETH,$P_DAI,$P_USDT,$P_USDC,$P_WBTC,$P_YFII,$P_QUSD,$P_HUSD,$P_UNI]
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$MOCK_TOKEN,0x0000000000000000000000000000000000000000,false
# 给 PiggyDistribution转入对应的代币
npx oz send-tx --to $MOCK_TOKEN --method transfer --args $PIGGY_DISTRIBUTION,1e20
# 挖矿
npx oz send-tx --to $PIGGY_DISTRIBUTION --method _stakeTokenToPiggyBreeder --args $MOCK_TOKEN,0

# piggyBreeder,add pool
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_ETH,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_DAI,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_USDT,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_USDC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_WBTC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_USDC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_YFII,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_QUSD,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_HUSD,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$P_UNI,0x0000000000000000000000000000000000000000,false

END=`date +%s`

print_success "\nDone. Runtime: $((END-START)) seconds."

exit 1