#!/bin/bash
set -x
set -e

source .env.kovan.qa

output_file=deployed.kovan_qa.env

START=`date +%s`

print_progress () {
  printf "\e[0;33m$1\e[0m\n"
}

print_success () {
  printf "\e[4;32m$1\e[0m\n"
}

npx oz link @openzeppelin/contracts-ethereum-package

npx oz compile --solc-version=0.6.12 --optimizer on

npx oz session --network $NETWORK

# deploy timeLock
TIME_LOCK=`npx oz deploy -k regular -n $NETWORK Timelock 0xb7eAF4e542D843eb322D21F935a7227277aa393b 172800`
print_progress "TIME_LOCK = $TIME_LOCK"
echo "TIME_LOCK=$TIME_LOCK" >> $output_file

# deploy WPC
WPC=`npx oz deploy -k regular -n $NETWORK WePiggyToken`
print_progress "WPC = $WPC"
echo "WPC=$WPC" >> $output_file

 deploy fundingManager
FUNDING_MANAGER=`npx oz deploy -k regular -n $NETWORK FundingManager $WPC`
print_progress "FUNDING_MANAGER = $FUNDING_MANAGER"
echo "FUNDING_MANAGER=$FUNDING_MANAGER" >> $output_file

# deploy fundingHolder
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

# deploy piggyBreeder
PIGGY_BREEDER=`npx oz deploy -k regular -n $NETWORK PiggyBreeder $WPC $FUNDING_MANAGER 1000000000000000000 22236933 22236935 5760 999 39`
print_progress "PIGGY_BREEDER = $PIGGY_BREEDER"
echo "PIGGY_BREEDER=$PIGGY_BREEDER" >> $output_file

# add fundingHolder to fundingManager
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args InsurancePayment,$FUNDING_HOLDER_INSURANCE_PAYMENT,30
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args ResourceExpansion,$FUNDING_HOLDER_RESOURCE_EXPANSION,25
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamVote,$FUNDING_HOLDER_TEAM_VOTE,20
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamSpending,$FUNDING_HOLDER_TEAM_SPENDING,18
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args CommunityRewards,$FUNDING_HOLDER_COMMUNITY_REWARDS,7

# wpc,grant miner role to piggyBreeder
npx oz send-tx --to $WPC --method grantRole --args 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6,$PIGGY_BREEDER

# piggyBreeder,add pool
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$cETH,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$cDAI,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$cUSDT,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$aETH,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$aDAI,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$aUSDT,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$cUSDC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$cWBTC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$aUSDC,0x0000000000000000000000000000000000000000,false
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$aWBTC,0x0000000000000000000000000000000000000000,false

# =========================================================================== #
# deploy SimplePriceOracle
SIMPLE_PRICE_ORAClE=`npx oz create -n $NETWORK SimplePriceOracle --init initialize`
print_progress "SIMPLE_PRICE_ORAClE = $SIMPLE_PRICE_ORAClE"
echo "SIMPLE_PRICE_ORAClE=$SIMPLE_PRICE_ORAClE" >> $output_file

# deploy Comptroller
COMPTROLLER=`npx oz create -n $NETWORK Comptroller --init initialize`
print_progress "COMPTROLLER = $COMPTROLLER"
echo "COMPTROLLER=$COMPTROLLER" >> $output_file

 deploy JumpRateModel
JUMP_RATE_MODEL=`npx oz create -n $NETWORK JumpRateModel --init initialize --args 0.05e18,0.45e18,0.25e18,0.95e18`
print_progress "JUMP_RATE_MODEL = $JUMP_RATE_MODEL"
echo "JUMP_RATE_MODEL=$JUMP_RATE_MODEL" >> $output_file

# deploy pTokens
P_ETH=`npx oz create -n $NETWORK PEther --init initialize --args $COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ ETH\",\"pETH\",8`
print_progress "P_ETH = $P_ETH"
echo "P_ETH=$P_ETH" >> $output_file

# notice: In Kovan Testnet Network ,the underlying of cToken is different from the underlyingAssetAddress of aToken
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

# mock send price to SimplePriceOracle
# notice: In Kovan Testnet Network ,the underlying of cToken is different from the underlyingAssetAddress of aToken
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $ETH,453294999000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $DAI,1007523000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $USDT,1000000000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $USDC,1000000000000000000000000000000
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $WBTC,453294999000000000000

# config Comptroller
npx oz send-tx --to $COMPTROLLER --method _setMaxAssets --args 200
npx oz send-tx --to $COMPTROLLER --method _setPriceOracle --args $SIMPLE_PRICE_ORAClE
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_ETH
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_DAI
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_USDT
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_USDC
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_WBTC
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_ETH,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_DAI,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_USDT,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_USDC,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_WBTC,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCloseFactor --args 0.5e18
npx oz send-tx --to $COMPTROLLER --method _setDistributeWpcPaused --args true

# config pToken
npx oz send-tx --to $P_ETH --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_DAI --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_USDT --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_USDC --method _setReserveFactor --args 0.1e18
npx oz send-tx --to $P_WBTC --method _setReserveFactor --args 0.1e18

# deploy ATokenMigrator
A_ETH_MIGRATOR=`npx oz deploy -k regular -n $NETWORK ATokenMigrator $PIGGY_BREEDER 0 $P_ETH`
print_progress "A_ETH_MIGRATOR = $A_ETH_MIGRATOR"
echo "A_ETH_MIGRATOR=$A_ETH_MIGRATOR" >> $output_file

A_DAI_MIGRATOR=`npx oz deploy -k regular -n $NETWORK ATokenMigrator $PIGGY_BREEDER 0 $P_DAI`
print_progress "A_DAI_MIGRATOR = $A_DAI_MIGRATOR"
echo "A_DAI_MIGRATOR=$A_DAI_MIGRATOR" >> $output_file

A_USDT_MIGRATOR=`npx oz deploy -k regular -n $NETWORK ATokenMigrator $PIGGY_BREEDER 0 $P_USDT`
print_progress "A_USDT_MIGRATOR = $A_USDT_MIGRATOR"
echo "A_USDT_MIGRATOR=$A_USDT_MIGRATOR" >> $output_file

A_USDC_MIGRATOR=`npx oz deploy -k regular -n $NETWORK ATokenMigrator $PIGGY_BREEDER 0 $P_USDC`
print_progress "A_USDC_MIGRATOR = $A_USDC_MIGRATOR"
echo "A_USDC_MIGRATOR=$A_USDC_MIGRATOR" >> $output_file

A_WBTC_MIGRATOR=`npx oz deploy -k regular -n $NETWORK ATokenMigrator $PIGGY_BREEDER 0 $P_WBTC`
print_progress "A_WBTC_MIGRATOR = $A_WBTC_MIGRATOR"
echo "A_WBTC_MIGRATOR=$A_WBTC_MIGRATOR" >> $output_file

npx oz send-tx --to $PIGGY_BREEDER --method setMigrator --args 0,$A_ETH_MIGRATOR
npx oz send-tx --to $PIGGY_BREEDER --method setMigrator --args 1,$A_DAI_MIGRATOR
npx oz send-tx --to $PIGGY_BREEDER --method setMigrator --args 2,$A_USDT_MIGRATOR
npx oz send-tx --to $PIGGY_BREEDER --method setMigrator --args 3,$A_USDC_MIGRATOR
npx oz send-tx --to $PIGGY_BREEDER --method setMigrator --args 4,$A_WBTC_MIGRATOR

END=`date +%s`

print_success "\nDone. Runtime: $((END-START)) seconds."

exit 1