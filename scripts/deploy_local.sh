#!/bin/bash
set -x
set -e

source .env.local.dev

output_file=deployed.local_dev.env

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

# Mock erc20
MOCK_TOKEN=`npx oz deploy -k regular -n $NETWORK MockERC20 \"Mock\ Token\" \"MC\" 1e27`
print_progress "MOCK_TOKEN = $MOCK_TOKEN"
echo "MOCK_TOKEN=$MOCK_TOKEN" >> $output_file

TIME_LOCK=`npx oz deploy -k regular -n $NETWORK Timelock 0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e 172800`
print_progress "TIME_LOCK = $TIME_LOCK"
echo "TIME_LOCK=$TIME_LOCK" >> $output_file

WPC=`npx oz deploy -k regular -n $NETWORK WePiggyToken`
print_progress "WPC = $WPC"
echo "WPC=$WPC" >> $output_file

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

PIGGY_BREEDER=`npx oz deploy -k regular -n $NETWORK PiggyBreeder $WPC $FUNDING_MANAGER 1000000000000000000 100 200 20 999 39`
print_progress "PIGGY_BREEDER = $PIGGY_BREEDER"
echo "PIGGY_BREEDER=$PIGGY_BREEDER" >> $output_file

npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args InsurancePayment,$FUNDING_HOLDER_INSURANCE_PAYMENT,30
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args ResourceExpansion,$FUNDING_HOLDER_RESOURCE_EXPANSION,25
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamVote,$FUNDING_HOLDER_TEAM_VOTE,20
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args TeamSpending,$FUNDING_HOLDER_TEAM_SPENDING,18
npx oz send-tx --to $FUNDING_MANAGER --method addFunding --args CommunityRewards,$FUNDING_HOLDER_COMMUNITY_REWARDS,7

# wpc,grant miner role to piggyBreeder
npx oz send-tx --to $WPC --method grantRole --args 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6,$PIGGY_BREEDER

# deploy SimplePriceOracle
SIMPLE_PRICE_ORAClE=`npx oz create -n $NETWORK SimplePriceOracle --init initialize`
print_progress "SIMPLE_PRICE_ORAClE = $SIMPLE_PRICE_ORAClE"
echo "SIMPLE_PRICE_ORAClE=$SIMPLE_PRICE_ORAClE" >> $output_file

# deploy Comptroller
COMPTROLLER=`npx oz create -n $NETWORK Comptroller --init initialize`
print_progress "COMPTROLLER = $COMPTROLLER"
echo "COMPTROLLER=$COMPTROLLER" >> $output_file

# deploy JumpRateModel
JUMP_RATE_MODEL=`npx oz create -n $NETWORK JumpRateModel --init initialize --args 0.05e18,0.45e18,0.25e18,0.95e18`
print_progress "JUMP_RATE_MODEL = $JUMP_RATE_MODEL"
echo "JUMP_RATE_MODEL=$JUMP_RATE_MODEL" >> $output_file

# deploy pTokens
P_ETH=`npx oz create -n $NETWORK PEther --init initialize --args $COMPTROLLER,$JUMP_RATE_MODEL,0.2e27,\"WePiggy\ ETH\",\"pETH\",8`
print_progress "P_ETH = $P_ETH"
echo "P_ETH=$P_ETH" >> $output_file

# deploy PiggyDistribution
PIGGY_DISTRIBUTION=`npx oz create -n $NETWORK PiggyDistribution --init initialize --args $MOCK_TOKEN,$PIGGY_BREEDER,$COMPTROLLER`
print_progress "PIGGY_DISTRIBUTION = $PIGGY_DISTRIBUTION"
echo "PIGGY_DISTRIBUTION=$PIGGY_DISTRIBUTION" >> $output_file

# mock send price to SimplePriceOracle
npx oz send-tx --to $SIMPLE_PRICE_ORAClE --method setPrice --args $ETH,453294999000000000000

# config Comptroller
npx oz send-tx --to $COMPTROLLER --method _setMaxAssets --args 200
npx oz send-tx --to $COMPTROLLER --method _setPriceOracle --args $SIMPLE_PRICE_ORAClE
npx oz send-tx --to $COMPTROLLER --method _supportMarket --args $P_ETH
npx oz send-tx --to $COMPTROLLER --method _setCollateralFactor --args $P_ETH,0.75e18
npx oz send-tx --to $COMPTROLLER --method _setCloseFactor --args 0.5e18
npx oz send-tx --to $COMPTROLLER --method _setPiggyDistribution --args $PIGGY_DISTRIBUTION

# config pToken
npx oz send-tx --to $P_ETH --method _setReserveFactor --args 0.1e18

# config PiggyDistribution
npx oz send-tx --to $PIGGY_DISTRIBUTION --method _addWpcMarkets --args [$P_ETH]

# piggyBreeder,add pool
npx oz send-tx --to $PIGGY_BREEDER --method add --args 1000,$MOCK_TOKEN,0x0000000000000000000000000000000000000000,false

# 给 PiggyDistribution转入对应的代币
npx oz send-tx --to $MOCK_TOKEN --method transfer --args $PIGGY_DISTRIBUTION,1e20

npx oz send-tx --to $PIGGY_DISTRIBUTION --method _stakeTokenToPiggyBreeder --args $MOCK_TOKEN,0

END=`date +%s`

print_success "\nDone. Runtime: $((END-START)) seconds."

exit 1