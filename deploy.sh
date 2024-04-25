#!/bin/bash

# check if network parameter is passed
if [ -z "$1" ]
then
  echo "Usage: $0 <network>"
  exit 1
fi

NETWORK=$1

npx hardhat run scripts/deploy/1-deploy.ts --network $NETWORK && 
npx ts-node scripts/deploy/2-check-roles.ts --no-compile --network $NETWORK && 
npx hardhat run scripts/deploy/3-configure.ts --no-compile --network $NETWORK && 
# npx hardhat run scripts/deploy/4-connect.ts --no-compile --network $NETWORK &&
npx hardhat run scripts/deploy/5-verify.ts --no-compile --network $NETWORK
